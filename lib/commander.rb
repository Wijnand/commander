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
        unless running.include? item.id
          running.push item.id
          pid = Process.fork {
              Process.fork {
              output=`#{item.command}`
              item.exitstatus = $?.exitstatus
              item.output = output
              saved = false
              until saved
                saved = item.save
                sleep 3 unless saved
              end
            }
            exit
          }
          DaemonKit.logger.info("Started process #{pid} for item #{item.id}: #{item.command}")
          Process.detach pid
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
      if e.message == "exit"
        exit
      end
      DaemonKit.logger.info("Unknown error: #{e.message}")
      sleep config['interval']
      retry
    end
  end
end
