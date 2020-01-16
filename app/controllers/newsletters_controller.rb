# frozen_string_literal: true

# Controller for newsletter
class NewslettersController < ApplicationController
  layout 'metrics_page'
  skip_before_action :authenticate_user!, only: %i[
    subscribe unsubscribe post_unsubscribe
  ]

  def index
    @newsletters = Newsletter.all.decorate
  end

  def create
    newsletter = Newsletter.new(newsletter_params)

    if newsletter.save
      flash[:toast] = { type: 'success', message: ['Newsletter sent'] }
      render js: "window.location='#{newsletter_path(newsletter)}'"
    else
      render json: { message: 'Send Failed' }, status: :unprocessable_entity
    end
  end

  def show
    @newsletter = Newsletter.find(params[:id])

    return unless request.xhr?

    render json: {
      html: render_to_string('newsletters/_modal.haml', layout: false)
    }
  end

  def subscribers
    @subscribers = NewsletterSubscription.where(subscribed: true).decorate
  end

  def subscribe
    sub_fail_action('No Email') if params[:email].blank?

    email = params[:email]

    sub = NewsletterSubscription.where(email: email).first_or_create
    sub.subscribed = true
    sub.save ? sub_pass_action : sub_fail_action('Subscription Failed')
  end

  def self_subscribe
    email = current_user.email
    sub_fail_action('No Email') if email.blank?

    sub = NewsletterSubscription.where(email: email).first_or_create
    sub.subscribed = true
    if sub.save
      flash[:toast] = { type: 'success', message: ['Newsletter Subscribed'] }
      render js: "window.location='#{settings_users_path}'"
    else
      sub_fail_action('Subscription Failed')
    end
  end

  def unsubscribe
    render layout: false
  end

  def self_unsubscribe
    newsletter_subscription =
      NewsletterSubscription.find_by(email: current_user.email)
    newsletter_subscription.update(subscribed: false)
    if newsletter_subscription.save
      flash[:toast] = { type: 'success', message: ['Newsletter Unsubscribed'] }
      render js: "window.location='#{settings_users_path}'"
    else
      sub_fail_action('Unsubscription Failed')
    end
  end

  def post_unsubscribe
    feedback = NewsletterFeedback.create(unsubscribe_params)

    if feedback.errors.any?
      render json: { message: feedback.errors.full_messages.join(', ') },
             status: :unprocessable_entity
    else
      # Prevent Oracle attack on newsletter subscribers list by returning as
      # long as the params syntax are correct
      render json: { message: 'Newsletter Unsubscribed! Hope to see you again' }
    end
  end

  private

  def newsletter_params
    params.require(:newsletter).permit(:title, :content)
  end

  def unsubscribe_params
    p = params.require(:newsletter_unsubscription).permit(:email, reasons: [])

    {
      newsletter_subscription: NewsletterSubscription.find_by(email: p[:email]),
      reasons: p[:reasons]
    }
  end

  def sub_pass_action
    render json: { message: 'Thanks for subscribing' }
  end

  def sub_fail_action(message)
    render json: { message: message }, status: :unprocessable_entity
  end
end
