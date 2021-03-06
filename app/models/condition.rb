class Condition < ActiveRecord::Base
  has_many :condition_trials
  has_many :clinical_trials, :through => :condition_trials, :uniq => true
  acts_as_trial_aggregator
end
