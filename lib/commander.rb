class Commander < ActiveResource::Base
  
  def self.run(config)
    self.site = config['url']
    self.user = config['user']
    self.password = config['pass']
  end
end