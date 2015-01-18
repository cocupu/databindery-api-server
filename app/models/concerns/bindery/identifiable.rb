module Bindery::Identifiable
  
  def generate_uuid
    if persistent_id
      return persistent_id
    else
      return self.persistent_id= UUID.new.generate if !persistent_id
    end
  end

end