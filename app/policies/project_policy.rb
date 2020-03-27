# frozen_string_literal: true

# Class for Project policies
class ProjectPolicy < ApplicationPolicy
  relation_scope do |relation|
    next relation if user&.admin?

    relation.where(visibility: true).or(
      relation.where(user_id: user&.id)
    )
  end

  def show?
    record.user_id == user&.id || record.visibility || user&.admin?
  end
end
