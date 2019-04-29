module AccountReset
  class Cancel
    include ActiveModel::Model
    include CancelTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      if success
        notify_user_via_email_of_account_reset_cancellation
        notify_user_via_phone_of_account_reset_cancellation if phone.present?
        update_account_reset_request
      end

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :token

    def notify_user_via_email_of_account_reset_cancellation
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_reset_cancel(email_address).deliver_later
      end
    end

    def notify_user_via_phone_of_account_reset_cancellation
      SmsAccountResetCancellationNotifierJob.perform_now(phone: phone)
    end

    def update_account_reset_request
      account_reset_request.update!(cancelled_at: Time.zone.now,
                                    request_token: nil,
                                    granted_token: nil)
    end

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def phone
      MfaContext.new(user).phone_configurations.take&.phone
    end

    def extra_analytics_attributes
      {
        event: 'cancel',
        user_id: user.uuid,
      }
    end
  end
end
