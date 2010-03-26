require 'hpricot'

class TrialsParser

  def initialize  
  end
  
  def parse_file(file_path)
    xml = File.read(file_path)
    doc = Hpricot::XML(xml)
    url = (doc/:required_header/:url).text
    nct_id = (doc/:id_info/:nct_id).text
    org_study_id = (doc/:org_study_id).text
    brief_title = (doc/:brief_title).text
    official_title = (doc/:official_title).text
    lead_sponsor_name = (doc/:sponsors/:lead_sponsor/:agency).text
    collaborator_elements = doc.at('sponsors').search('collaborator')
    authorities = doc.at('oversight_info').search('authority')
    source = (doc/:source).text
    has_dmc = (doc/:oversight_info/:has_dmc).text
    if has_dmc == 'Yes'
      has_data_monitoring_committee = true
    elsif has_dmc == 'No'
      has_data_monitoring_committee = false
    else
      has_data_monitoring_committee = nil
    end
    summary = (doc/:brief_summary/:textblock).text
    overall_status = (doc/:overall_status).text
    why_stopped = (doc/:why_stopped).text
    phase = (doc/:phase).text
    start_date = (doc/:start_date).text
    end_date = (doc/:end_date).text
    completion_date = doc.at('completion_date') ? doc.at('completion_date').inner_text : nil
    completion_date_type = doc.at('completion_date') ? doc.at('completion_date').attributes['type'] : nil
    primary_completion_date = doc.at('primary_completion_date') ? doc.at('primary_completion_date').inner_text : nil
    primary_completion_date_type = doc.at('primary_completion_date') ? doc.at('primary_completion_date').attributes['type'] : nil
    phase = (doc/:phase).text
    study_type = (doc/:study_type).text
    study_design = (doc/:study_design).text
    if number_of_arms = (doc/:number_of_arms)
      number_of_arms = number_of_arms.text
    end
    if number_of_groups = (doc/:number_of_groups)
      number_of_groups = number_of_groups.text
    end
    if enrollment = doc.at('enrollment')
      enrollment_type = enrollment.attributes['type']
      enrollment = enrollment.inner_text
    else
      enrollment_type = nil
    end
    trial = ClinicalTrial.create(:url => url, 
                                 :nct_id => nct_id, 
                                 :org_study_id => org_study_id,
                                 :brief_title => brief_title,
                                 :official_title => official_title,
                                 :source => source, 
                                 :has_data_monitoring_committee => has_data_monitoring_committee,
                                 :summary => summary, 
                                 :overall_status => overall_status,
                                 :why_stopped => why_stopped, 
                                 :phase => phase,
                                 :start_date => start_date, 
                                 :end_date => end_date,
                                 :completion_date => completion_date,
                                 :completion_date_type => completion_date_type,
                                 :primary_completion_date => primary_completion_date,
                                 :primary_completion_date_type => primary_completion_date_type,
                                 :phase => phase,
                                 :study_type => study_type, 
                                 :study_design => study_design, 
                                 :number_of_arms => number_of_arms,
                                 :number_of_groups => number_of_groups,
                                 :enrollment => enrollment,
                                 :enrollment_type => enrollment_type
                                 )
    doc.search('overall_official').each do |official|
      overall_official = OverallOfficial.new(:name => official.at('last_name').inner_text)
      if official.at('role')
        overall_official.role = official.at('role').inner_text
      end
      if official.at('affiliation')
        affiliation = official.at('affiliation').inner_text
        agency = Agency.find_or_create_by_name(affiliation)
        overall_official.agency_id = agency.id
      end
      overall_official.save!
    end             
    # TODO NEED TO ADD OVERALL_CONTACT SECTION                
    if doc.search('primary_outcome')
      primary_outcome = Outcome.new(:clinical_trial_id => trial.id, 
                                    :outcome_type => 'primary', 
                                    :measure => (doc/:primary_outcome/:measure).text)
      if time_frame = (doc/:primary_outcome/:time_frame)
        primary_outcome.time_frame = time_frame.text
      end
      if safety_issue = (doc/:primary_outcome/:safety_issue)
        primary_outcome.safety_issue = safety_issue.text
      end
      if description = (doc/:primary_outcome/:description)
        primary_outcome.description = description.text
      end
      primary_outcome.save!
    end
    if doc.search('secondary_outcome')
      secondary_outcome = Outcome.new(:clinical_trial_id => trial.id, 
                                    :outcome_type => 'secondary', 
                                    :measure => (doc/:secondary_outcome/:measure).text)
      if time_frame = (doc/:secondary_outcome/:time_frame)
        secondary_outcome.time_frame = time_frame.text
      end
      if safety_issue = (doc/:secondary_outcome/:safety_issue)
        secondary_outcome.safety_issue = safety_issue.text
      end
      if description = (doc/:secondary_outcome/:description)
        secondary_outcome.description = description.text
      end
      secondary_outcome.save!
    end
    authorities.each do |authority_name|
      authority = Authority.create(:name => authority_name.inner_text)
      Overseer.create(:authority_id => authority.id, 
                      :clinical_trial_id => trial.id)
    end                          
    agency = Agency.find_or_create_by_name(lead_sponsor_name)
    lead_sponsor = Sponsor.create(:agency_id => agency.id, 
                                  :clinical_trial_id => trial.id, 
                                  :role => 'lead')
    collaborator_elements.each do |collaborator|
      collaborator_name = collaborator.inner_text
      agency = Agency.find_or_create_by_name(collaborator_name)
    end
    doc.search("location").each do |location|
      facility_name = location.at("facility name") ? location.at("facility name").inner_text : nil
      address = location.at("address")
      city = address.at('city').inner_text
      state = address.at('state') ? address.at('state').inner_text : nil
      zip = address.at('zip') ? address.at('zip').inner_text : nil
      country = address.at('country').inner_text
      status = location.at('status').inner_text

      facility = Facility.create(:name => facility_name, 
                                 :city => city,
                                 :state => state, 
                                 :zip => zip, 
                                 :country => country)
       if contact = location.at('contact')
         last_name = contact.at('last_name').inner_text
         phone = contact.at('phone').inner_text
         phone_ext = contact.at('phone_ext').inner_text
         email = contact.at('email').inner_text
         contact = Contact.create(:last_name => last_name,
                                  :phone => phone,
                                  :phone_ext => phone_ext,
                                  :email => email)
       end
       if backup_contact = location.at('contact_backup')
         last_name = backup_contact.at('last_name').inner_text
         phone = backup_contact.at('phone').inner_text
         phone_ext = backup_contact.at('phone_ext').inner_text
         email = backup_contact.at('email').inner_text
         backup_contact = Contact.create(:last_name => last_name,
                                  :phone => phone,
                                  :phone_ext => phone_ext,
                                  :email => email)
       end
       location_model = Location.create(:facility_id => facility.id, 
                                        :trial_id => trial.id, 
                                        :status => status,
                                        :contact => contact,
                                        :backup_contact => backup_contact)
       location.search('investigator').each do |investigator|
         if investigator.at('role')
           role = investigator.at('role').inner_text
         else
           role = nil
         end
         Investigator.create(:last_name => investigator.at("last_name").text, 
                             :role => role,
                             :location_id => location_model.id)
       end
    end
  end
end
