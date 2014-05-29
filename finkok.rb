# encoding: utf-8
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
      base = entorno == :production ? 'https://facturacion.finkok.com/servicios/soap' : 'http://demo-facturacion.finkok.com/servicios/soap'
      
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
     
       puts data

       return ({
         uuid: data[:uuid],
         timbre: data[:sat_seal],
         no_certificado_sat: data[:no_certificado_sat],
         xml: data[:xml]
       })
    end
  
    def cancela uuid, rfc, key, cert
      uuid = [uuid] unless uuid.is_a? Array 
    
      client = Savon.client(wsdl: @cancel, log_level: :debug, log: false)
    
      uuid.map! do |u|
        u = "<tns:string>#{u}</tns:string>"
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
    
      data = response.hash[:envelope][:body][:cancel_response][:cancel_result]

      if data[:folios]
        status = data[:folios][:folio][:estatus_uuid]
        if status == "201"
          return data[:folios][:acuse];
        end

        raise ErrorCancelacion.new status.to_i
      end

      raise ErrorCancelacion.new(900, response.hash)
    
    end

    def recibo_cancelacion (uuid, emisor)
      client = Savon.client(wsdl: @cancel, log_level: :error, log: false)
      
      xml = <<XML
      <tns:uuid>#{uuid}</tns:uuid>
      <tns:username>#{@usuario}</tns:username>
      <tns:password>#{@password}</tns:password>
      <tns:taxpayer_id>#{emisor}</tns:taxpayer_id>
XML

      response = client.call :get_receipt, message: xml

      body = response.hash[:envelope][:body][:get_receipt_response][:get_receipt_result]
      if body[:error]
        raise body[:error]
      end

    end
  
  end
  
  
  class Error < StandardError
    
    attr_accessor :code
    ERRORES = {
      '300' => 'Usuario y contraseña inválidos',
      '301' => 'XML mal formado (Error que no se que signifique)',
      '302' => 'Sello mal formado',
      '303' => 'Sello no corresponde al emisor',
      '305' => 'Fecha de emisión no está dentro de la vigencia del Certificado',
      '304' => 'Certificado revocado o caduco',
      
      '401' => 'Fecha y hora de generación fuera de rango',
      
      '705' => 'Estructura de XML mal formada (Error de Sintaxis)',

      '708' => 'Error de conexión con el SAT'
    }
    
    def initialize (code)
      @code = code
      super ERRORES[code]
    end
    
  end

  class ErrorCancelacion < StandardError
    attr_accessor :code, :data
    ERRORES = {
      202 => 'Cancelado Previamente',
      203 => 'No corresponde el RFC del emisor y de quien solicita la cancelación',
      205 => 'No existente',
      900 => 'Error de PAC',
      708 => 'Error de conexión con el SAT'
    }


    def initialize (code, data=nil)
      @code = code
      @data = data
      msg = ERRORES[code] || "Error #{code}"
      super msg
    end
  end
  
  
end
