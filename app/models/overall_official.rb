class OverallOfficial < ActiveRecord::Base
  belongs_to :agency
  belongs_to :clinical_trial
end
