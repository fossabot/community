class Api::SettingsController < Api::ApiController
  skip_authorization_check only: :update

  def update
    puts settings_params
    current_user.update!(settings_params)
    render json: {}
  end

private
  def settings_params
    params.require(:settings).permit(:email_on_mention, :subscribe_on_create, :subscribe_when_mentioned)
  end
end
