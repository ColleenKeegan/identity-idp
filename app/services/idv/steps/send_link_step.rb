module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      def call
        capture_doc = CaptureDoc::CreateRequest.call(current_user.id)
        begin
          SmsDocAuthLinkJob.perform_now(
            phone: permit(:phone)[:phone],
            link: link(capture_doc.request_token),
            app: 'login.gov',
          )
        rescue Twilio::REST::RestError, PhoneVerification::VerifyError
          return failure(I18n.t('errors.messages.invalid_phone_number'))
        end
      end

      private

      def form_submit
        Idv::PhoneForm.new(previous_params: {}, user: current_user).submit(permit(:phone))
      end

      def link(token)
        idv_capture_doc_step_url(step: :mobile_front_image, token: token)
      end
    end
  end
end
