module AccountReset
  class RequestController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_multiple_factors_enabled
    before_action :confirm_user_not_verified

    def show
      analytics.track_event(Analytics::ACCOUNT_RESET_VISIT)
    end

    def create
      analytics.track_event(Analytics::ACCOUNT_RESET, analytics_attributes)
      AccountReset::CreateRequest.new(current_user).call
      flash[:email] = current_user.email_addresses.take.email
      redirect_to account_reset_confirm_request_url
    end

    private

    def confirm_multiple_factors_enabled
      return if multiple_factors_enabled?

      redirect_to two_factor_options_url
    end

    def confirm_user_not_verified
      # IAL2 users should not be able to reset account to comply with AAL2 reqs
      redirect_to account_url if decorated_user.identity_verified?
    end

    def analytics_attributes
      {
        event: 'request',
        sms_phone: TwoFactorAuthentication::PhonePolicy.new(current_user).configured?,
        totp: TwoFactorAuthentication::AuthAppPolicy.new(current_user).configured?,
        piv_cac: TwoFactorAuthentication::PivCacPolicy.new(current_user).configured?,
        email_addresses: current_user.email_addresses.count,
      }
    end
  end
end
