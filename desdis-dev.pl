#!usr/bin/perl
#
# Programa para permitir descargas distribuidas de archivos desde internet.
#   Comenzado en Agosto 2010
# Este programa se entrega bajo la licencia MIT
#
# Copyright (c) 2010 Ariset Llerena Tapia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

use strict;
use warnings;
use HTTP::Response;

BEGIN{
	umask 755;
	sub linea_bonita();
	sub obtener_uri();
	sub obtener_nombre_fichero();
	sub obtener_head($);
	sub calcular_ideal($);
}
INIT{
	linea_bonita();
}
END{
	print "\n";
	linea_bonita();
	exit(0);
}


#my $uri = 'http://ftp.heanet.ie/pub/ubuntu-cdimage/releases/lucid/release/ubuntu-10.04-dvd-i386.iso';
my $uri = 'http://www.example.com';
my $nombre_fichero = "file";
print  $uri;

my $fichero_destino;
my $respuesta;

$uri = obtener_uri();
$nombre_fichero = obtener_nombre_fichero();
$respuesta = obtener_head($uri);


if($respuesta->is_success()){
	my $content_length; # :)
    my $pedazos;	# bloques totales
    my $tamano;		# tamaño de cada bloque
    my $pedazo_actual;  # comienza en 1
    my ($byte_inicio, $byte_final); # bytes del archivo a descargar

    $content_length = $respuesta->header("Content-Length");

	print("El fichero especificado existe\n");
	print("El tamano del fichero es $content_length bytes\n");

	print("Escriba la cantidad de bloques en que desea dividir el fichero: ");
	chomp($pedazos = <STDIN>);
	$tamano = int($content_length / $pedazos);

	print("Se dividira el fichero en $pedazos bloques de $tamano bytes c/u\n");
	print("Elija el bloque a descargar (1 a $pedazos): ");
	chomp($pedazo_actual = <STDIN>);

	my $fichero_destino = sprintf("%s.%02d.%03d", $nombre_fichero, $pedazos, $pedazo_actual);

	# calcular donde comienza y donde termina
	if(-e $fichero_destino){
	    # fichero existe, entonces continuar la descarga
	    # calcular dónde comienza la continuación de la descarga
	    print("Preparando la continuación de la descarga...\r");
	    my $tmp = "tmp";
	    my $comando = "curl --silent --show-error --head file://$fichero_destino --output $tmp";
		system($comando);
		
	    my $tmp_file;
		open($tmp_file, '<', $tmp);

		my $largo = <$tmp_file>;
		close($tmp_file);
		unlink($tmp);

		$largo =~ m/(\d{1,})/;
		$largo = $1;
		#print($largo."\n");
		if($tamano == $largo){
			print("Este bloque [$pedazo_actual] ya esta descargado\n");
			exit(1);
		}
		$byte_inicio = $tamano * ($pedazo_actual - 1) + $largo + 1;
	}
	else {
		$byte_inicio = $tamano * ($pedazo_actual - 1);
	}
	# comprobar si el bloque es el último, ya que puede ser de menor tamaño
	#   que el resto
	if ($pedazo_actual == $pedazos){
		$byte_final = $content_length;
	} else {
		$byte_final = $tamano * ($pedazo_actual) - 1;
	}

	# acá uso >> para añadir al fichero si existe o crearlo en caso contrario
	my $comando = "curl --range $byte_inicio-$byte_final $uri >> $fichero_destino";
	system($comando);
} else {
	print("Ha ocurrido un error: " . $respuesta->status_line);
	exit(1);
}


# Línea bonita
sub linea_bonita(){
	print("=") for (1..80);
}

# Realiza un Head a la url de destino y la devuelve como HTTP::Response
sub obtener_head($){
	my $mi_uri = shift;
	#my $nombre_fichero_headers = "headers";
	my $headers;

	open($headers, '+<', undef);	# uso un fichero temporal en memoria
	#$comando = "curl --silent --show-error --head $mi_url --output $nombre_fichero_headers";
	my $comando = "curl --silent --show-error --head $mi_uri";
	print $headers (`$comando`);
	seek($headers, 0, 0);

	my $slash = $/;
	undef $/;	# todo el archivo
	my $_respuesta = HTTP::Response->parse(<$headers>);
	$/ = $slash;  # de vuelta a lo normal
	close($headers);

	## mejorar el manejo de file:
	if($uri =~ /^file/){
	    #$_respuesta->code($_respuesta->is_success()>0 ? 200 : 404);
	}
	##
	return $_respuesta;
}

sub obtener_uri(){
	my $_uri = $uri;
	print("Escriba la URI [$uri]: ");	chomp($_uri = <STDIN>);
	return length($_uri) ? $_uri : $uri;
}

sub obtener_nombre_fichero(){
	my $_nombre_fichero = $nombre_fichero;
	print("Donde desea guardar el fichero? [$nombre_fichero]: ");
	chomp($_nombre_fichero = <STDIN>);
	return length($_nombre_fichero) ? $_nombre_fichero : $nombre_fichero;
}

sub calcular_ideal($){
	my $num = shift;
	return sprintf("%.2f", log($num));
}