module Rack
  module Handler
    module WebrickCompat
      begin
        require 'rack/handler/webrick'
      rescue LoadError
        require 'rackup/handler/webrick'
        WEBrick = Class.new(Rackup::Handler::WEBrick)
      end
    end
  end
end