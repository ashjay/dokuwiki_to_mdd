class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def cas
    auth = request.env["omniauth.auth"]
    @user = User.where(email: auth["uid"].downcase).first
    if @user.present?
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to new_user_session_path error: t(:omniauth_invalid_user)
    end
  end
end
