# Programa para permitir descargas distribuidas de archivos desde internet.
#   Comenzado en Agosto 2010
# Este programa se entrega bajo la licencia MIT
#
# Copyright (c) 2010 Ariset Llerena
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

# BUG: corrompe el fichero si se descarga un bloque existente

#!usr/bin/perl
use strict;
use warnings;
use HTTP::Response;
umask 755;

# Línea bonita
print("=") for (1..80);

my $comando;
my $url;
my $fichero_destino;
my $nombre_fichero_headers = "headers";
my $respuesta;

my $nombre_fichero = "file.msi";
$url = 'http://downloads.activestate.com/ActivePerl/releases/5.12.1.1201/ActivePerl-5.12.1.1201-MSWin32-x64-292674.msi';

$comando = "curl --silent --show-error --head $url --output $nombre_fichero_headers";
system($comando);

{
	my $fichero_headers;
    open($fichero_headers, '<', $nombre_fichero_headers);
	undef $/;	# todo el archivo
	$respuesta = HTTP::Response->parse(<$fichero_headers>);
	$/ = "\n";  # de vuelta a lo normal
	close($fichero_headers);
	unlink($nombre_fichero_headers);
	
	if(-z $nombre_fichero_headers){
	    $respuesta->message("[Error de conección (?)]");
	}
}

if($respuesta->is_success()){
	my $content_length; # :)
    my $pedazos;    # bloques totales
    my $tamano;     # tama¤o de cada bloque
    my $pedazo_actual;  # comienza en 1
    my ($byte_inicio, $byte_final); # bytes del archivo a descargar

    $content_length = $respuesta->header("Content-Length");

	print("El fichero especificado existe\n");
	print("El tamaño del fichero es $content_length bytes\n");

	print("Escriba la cantidad de bloques en que desea dividir el fichero: ");
	chomp($pedazos = <>);
	$tamano = int($content_length / $pedazos);

	print("Se dividirá el fichero en $pedazos bloques de $tamano bytes c/u\n");
	print("Elija el bloque a descargar (1 a $pedazos): ");
	chomp($pedazo_actual = <>);

	my $fichero_destino = sprintf("%s.%02d.%03d", $nombre_fichero, $pedazos, $pedazo_actual);

	# calcular donde comienza y donde termina
	if(-e $fichero_destino){
	    # fichero existe, entonces continuar la descarga
	    # calcular dónde comienza la continuación de la descarga
	    my $tmp = "tmp";
	    $comando = "curl --silent --show-error --head file://$fichero_destino --output $tmp";
		system($comando);
		
	    my $tmp_file;
		open($tmp_file, '<', $tmp);

		my $largo = <$tmp_file>;
		close($tmp_file);
		unlink($tmp);

		$largo =~ m/(\d{1,})/;
		$largo = $1;
		print($largo."\n");
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
	#print("descargando...\n");
	#my $extra = "--progress-bar";
	# acá uso >> para añadir al fichero si existe o crearlo en caso contrario
	$comando = "curl --range $byte_inicio-$byte_final $url >> $fichero_destino";
	#print("Comando:\t$comando");
	#<>;
	system($comando);
} else {
	print("Ha ocurrido un error: " . $respuesta->status_line);
	exit(1);
}


# Línea bonita
print("\n");
print("=") for (1..80);
