require_relative 'finkok.rb'

usuario = 'un usuario'
password = 'un password'

# para hacerlo ya enserio, usas entorno: pruebas o nomás no lo usas
proveedor = FinkOK::Comprobante.new(usuario, password, entorno: 'pruebas')

# este xml tiene una fecha que debemos cambiar, además de generar el sello correspondiente, partiendo de
# la cadena original que debemos obtener desde antes, osea que es un pedo hacerlo
# a menos que uses algo como https://github.com/unRob/CFDI
xml = File.read('test.xml')

timbrada = proveedor.timbra(xml)
puts timbrada

# también cancela, pero como me dio hueva incluir los certificados y llaves...
# Obtener estos está documentado acá https://github.com/unRob/CFDI/blob/master/examples/crear_factura.rb
#puts proveedor.cancela timbrada[:uuid], 'AAD990814BP7', certificado.to_s, llave.to_s