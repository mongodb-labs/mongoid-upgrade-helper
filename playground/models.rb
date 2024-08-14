require 'mongoid'

class Person
  include Mongoid::Document

  belongs_to :team
  embeds_one :name

  has_many :positions

  field :pronouns, type: String
end

class Name
  include Mongoid::Document

  embedded_in :person

  field :prefix, type: String
  field :given, type: String
  field :surname, type: String
  field :suffix, type: String

  def full
    [ prefix, given, surname, suffix ].select(&:present?).join(' ')
  end
end

class Organization
  include Mongoid::Document

  field :name, type: String
end

class Company < Organization
  has_one :ceo_position, class_name: 'Position', as: :organization

  has_many :departments

  field :industry, type: String

  def ceo
    ceo_position.person
  end

  def teams
    Team.where(department: departments)
  end
end

class Department < Organization
  has_many :manager_positions, class_name: 'Position', as: :organization

  belongs_to :company
  has_many :teams

  def managers
    # ugh. might be a good place to test an agg pipeline query
    manager_positions.map(&:person)
  end
end

class Team < Organization
  has_one :supervisor_position, class_name: 'Position', as: :organization

  belongs_to :department

  has_many :members, class_name: 'Person'

  def supervisor
    supervisor_position.person
  end
end

class Position
  include Mongoid::Document

  belongs_to :organization, polymorphic: true
  belongs_to :person

  field :title, type: String
end
