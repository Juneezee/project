# frozen_string_literal: true

# == Schema Information
#
# Table name: invites
#
#  id         :bigint           not null, primary key
#  types      :enum             default("Invite"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_invites_on_project_id  (project_id)
#  index_invites_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Invite < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validate :not_owner
  validate :in_project

  validates :user_id, uniqueness: {
    scope: :project_id,
    message: 'has already been invited/applied'
  }

  after_commit :send_notification, on: :create

  # acts_as_notifiable :users,
  #                    targets: lambda { |invite, key|
  #                      if %w[accept.application invite.invite decline.application].include? key
  #                        [invite.user]
  #                      elsif %w[accept.invite invite.application decline.invite].include? key
  #                        [invite.project.user]
  #                      end
  #                    },
  #                    notifiable_path: :project_notifiable_path

  def managed?(manager)
    (manager&.admin? && user != manager) || manager == project.user
  end

  def send_resolve_notification(resolution)
    Notification.create(
      user: types == 'Invite' ? project.user : user,
      notifier: project, key: "#{resolution}/#{types.downcase}",
      notifiable: types == 'Invite' ? user : project
    )
  end

  private

  def project_notifiable_path
    project_path(project)
  end

  def send_notification
    target = types == 'Invite' ? user : project.user
    Notification.create(
      user: target, notifier: project, notifiable: self,
      key: "invite/#{types.downcase}"
    )
  end

  def not_owner
    errors[:base] << 'Owner cannot be added to project' if user == project&.user
  end

  def in_project
    errors[:base] << 'User already in project' if user&.in_project?(project)
  end
end