class Commander < ActiveResource::Base
  
  def self.running
    @running ||= []
  end
  
  def self.run(config)
    self.site = config['url']
    self.user = config['user']
    self.password = config['pass']
    self.element_name = "command"
    
    begin
      self.find(:all, :conditions => { :exitstatus => nil}).each do | item |
        if running.include? item.id
          DaemonKit.logger.debug "Already running job #{item.id}"
        else
          running.push item.id
          DaemonKit.logger.debug "Should run #{item.id}: #{item.command}"
          Process.fork {
            output=`#{item.command}`
            item.exitstatus = $?.exitstatus
            item.output = output
            item.save
          }
        end
      end
    rescue Errno::ECONNREFUSED
      DaemonKit.logger.info("Connection refused")
      sleep config['interval']
      retry
    rescue ActiveResource::ResourceNotFound
      DaemonKit.logger.info("404! It seems you are not pointing me to a compatible REST service")
      sleep config['interval']
      retry
    rescue ActiveResource::TimeoutError
      DaemonKit.logger.info("Timed out, will try again")
      sleep config['interval']
      retry
    rescue Exception => e
      DaemonKit.logger.info("Unknown error: #{e.message}")
      sleep config['interval']
      retry
    end
  end
end