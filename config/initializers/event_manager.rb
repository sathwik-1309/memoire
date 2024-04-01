require 'eventmachine'

module EventManager
  def self.start_event_machine
    Thread.new do
      EventMachine.run do

      end
    end
  end
end

EventManager.start_event_machine