module FinkOK
  class Comprobante
  
    require 'savon'
    require 'base64'
    require 'pp'
  
    attr_writer :usuario, :password
    @@entorno = 'produccion'
  
    def self.entorno
      return @@entorno
    end
  
    def self.entorno= entorno
      @@entorno = entorno
    end
  
    def self.produccion?
      return @@entorno == 'produccion'
    end
  
    def initialize(usuario, password, entorno: 'produccion')
      @usuario = usuario
      @password = password
      base = entorno == 'produccion' ? 'https://facturacion.finkok.com/servicios/soap' : 'http://demo-facturacion.finkok.com/servicios/soap'
      
      @stamp = "#{base}/stamp.wsdl"
      @cancel = "#{base}/cancel.wsdl"
   
    end
  
    def timbra (xml)
       client = Savon.client(wsdl: @stamp, log_level: :error)
     
       msg = {
         xml: Base64::encode64(xml.gsub(/\n/, '')),
         username: @usuario,
         password: @password
       }

       response = client.call :stamp, message: msg
       
       
       data = response.body[:stamp_response][:stamp_result]
     
       if data[:incidencias]
         error = data[:incidencias][:incidencia]
         error = error[0] unless !(error.is_a? Array);
         raise Error, error[:codigo_error]
       end
     
       return ({
         uuid: data[:uuid],
         timbre: data[:sat_seal],
         no_certificado_sat: data[:no_certificado_sat],
         xml: data[:xml]
       })
    end
  
    def cancela uuid, rfc, key, cert
      uuid = [uuid] unless uuid.is_a? Array 
    
      client = Savon.client(wsdl: @cancel)
    
      uuid.map! do |uuid|
        uuid = "<tns:string>#{uuid}</tns:string>"
      end
    
      # Usamos xml derecho porque savon se caga con el wsdl
      xml = <<XML
<tns:UUIDS>
	<tns:uuids>
  #{uuid.join "\n"}
	</tns:uuids>
</tns:UUIDS>
<tns:username>#{@usuario}</tns:username>
<tns:password>#{@password}</tns:password>
<tns:taxpayer_id>#{rfc}</tns:taxpayer_id>
<tns:cer>#{Base64::encode64(cert.to_s)}</tns:cer>
<tns:key>#{Base64::encode64(key.to_s)}</tns:key>
XML
     
      response = client.call(:cancel, message: xml)
    
      pp response.hash
    
    end
  
  end
  
  
  class Error < StandardError
        
    ERRORES = {
      '300' => 'Usuario y contraseña inválidos',
      '301' => 'XML mal formado (Error que no se que signifique)',
      '302' => 'Sello mal formado',
      '303' => 'Sello no corresponde al emisor',
      '305' => 'Fecha de emisión no está dentro de la vigencia del Certificado',
      '304' => 'Certificado revocado o caduco',
      
      '401' => 'Fecha y hora de generación fuera de rango',
      
      '705' => 'Estructura de XML mal formada (Error de Sintaxis)'
    }
    
    def initialize (code)
      super ERRORES[code]
    end
    
  end
  
  
end