module Viddler
  class Parser
    
    def self.parse(method, data)
      Errors.process(data)
      parser = Parser::PARSERS[method]
      parser.process(data)
    end
    
    def self.element(name, data)
      data = data.body rescue data # either data or an HTTP response
      doc = Hpricot.XML(data)
      doc.search(name) do |element|
        return element
      end
      raise "Element #{name} not found in #{data}"
    end
    
    def self.hash_or_value_for(element)
      if element.children.size == 1 && element.children.first.kind_of?(REXML::Text)
        element.text_value
      else
        hashinate(element)
      end
    end

    def self.hashinate(response_element)
      hash = {}
      response_element.children.reject{|e| e.kind_of? Hpricot::Text}.each do |elem|
        hash[elem.name.to_sym] = elem.inner_html
      end
      hash
    end
  
    class UsersAuth < Parser
      def self.process(data)
        element("sessionid", data).inner_html
      end
    end
    
    class VideosUpload < Parser
      def self.process(data)
        hashinate(element("video", data))
      end
    end
    
    PARSERS = {
      'viddler.users.auth' => UsersAuth,
      'viddler.videos.upload' => VideosUpload
    }
    
    class Errors < Parser
      EXCEPTIONS = {
        1 	=> Viddler::Session::UnknownError,
        2 	=> Viddler::Session::BadArgumentFormat,
        3 	=> Viddler::Session::UnknownArgument,
        4 	=> Viddler::Session::MissingRequiredArgument,
        5   => Viddler::Session::NoMethodSpecified,
        6   => Viddler::Session::UnknownMethodSpecified,
        7   => Viddler::Session::APIKeyMissing,
        8   => Viddler::Session::InvalidOrUnknownAPIKey,
        9   => Viddler::Session::InvalidOrExpiredSessionID,
        10  => Viddler::Session::HTTPMethodNotAllowed,
        11  => Viddler::Session::MethodRestrictedBySecurityLevel,
        12  => Viddler::Session::APIKeyDisabled
      }
      
      def self.process(data)
        response_element = element('error', data) rescue nil
        if response_element
          code = response_element.search('code').inner_html.to_i
          description = response_element.search('description').inner_html
          raise EXCEPTIONS[code], "Error #{code}- #{description}"
        end
      end
    end
  end
  
  
end