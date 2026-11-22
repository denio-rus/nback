class GameSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  # The breakdown page is for the owner only; the other actions allow anonymous play.
  before_action :require_authentication, only: :show
  before_action :set_active_game, only: %i[new create]
  before_action :set_game_session, only: %i[play submit_result]

  # The optional check-in form. Anonymous visitors have nobody to attach a
  # check-in to, so they go back to the game page, where Play starts at once.
  def new
    return redirect_to game_path(@game) unless Current.user

    @check_in = Current.user.check_ins.new
  end

  def create
    @check_in = build_check_in
    @game_session = @game.game_sessions.new(
      setup_game: @game.game_strategy.setup_game,
      user: Current.user
    )

    if @check_in&.invalid?
      render :new, status: :unprocessable_content
    elsif save_session_with(@check_in)
      redirect_to play_game_game_session_path(@game, @game_session)
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  end

  # Breakdown of one finished play-through. Only the owner finds it: someone
  # else's id, an anonymous session and an unfinished one are all a 404.
  def show
    @game_session = Current.user.game_sessions.where.not(played_at: nil).includes(:game, :check_in).find(params[:id])
    @game = @game_session.game
    @strategy = @game.game_strategy
    @trials = @strategy.trials(@game_session.result)
    @blocks = @trials.empty? ? [] : Games::Blocks.call(@trials, phases: @strategy.phases)
  end

  def play
  end

  def submit_result
    return render json: { error: "already_submitted" }, status: :conflict if @game_session.played_at

    strategy = @game.game_strategy
    result = strategy.handle_result(@game_session.setup_game, params[:result])

    if @game_session.update(
      played_at: Time.current,
      result: result,
      metric: strategy.primary_metric(result),
      metric_secondary: strategy.secondary_metric(result)
    )
      render json: @game_session, status: :ok
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  rescue Games::BaseStrategy::InvalidResult => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # No check-in for anonymous visitors, for "skip" and for a form left empty.
  def build_check_in
    return unless Current.user
    return if params[:skip].present?

    attributes = check_in_params
    return if check_in_blank?(attributes)

    Current.user.check_ins.new(attributes)
  end

  def check_in_params
    params.fetch(:check_in, {}).permit(:sleep_hours, :day_phase, flags: CheckIn::FLAGS)
  end

  # "0" and "false" are what an untouched checkbox sends, they are not an answer.
  # Any other value stays, so that the model can reject it.
  def check_in_blank?(attributes)
    attributes[:sleep_hours].blank? &&
      attributes[:day_phase].blank? &&
      attributes.fetch(:flags, {}).values.all? { |value| value.blank? || CheckIn::FALSE_VALUES.include?(value) }
  end

  # The check-in and the session are saved together or not at all.
  def save_session_with(check_in)
    GameSession.transaction do
      check_in&.save!
      @game_session.check_in = check_in
      @game_session.save || raise(ActiveRecord::Rollback)
    end
    @game_session.persisted?
  end

  def set_active_game
    @game = Game.where(active: true).find(params[:game_id])
  end

  # A session is reachable only through its own game. A session with an owner
  # is reachable only by that owner; anonymous sessions stay open by id.
  def set_game_session
    @game_session = GameSession.includes(:game).find_by!(id: params[:id], game_id: params[:game_id])
    @game = @game_session.game
    raise ActiveRecord::RecordNotFound unless owner_or_anonymous?(@game_session)
  end

  def owner_or_anonymous?(game_session)
    game_session.user_id.nil? || game_session.user_id == Current.user&.id
  end
end
