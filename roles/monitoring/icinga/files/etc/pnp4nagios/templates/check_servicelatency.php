<?php
#
$opt[1] = "--vertical-label \"Seconds\" --title=\"Service Check Latency\" ";
#
$def[1] =   rrd::def("max", $RRDFILE[1], $DS[1], "AVERAGE");
$def[1] .=  rrd::def("avg", $RRDFILE[1], $DS[2], "AVERAGE");
$def[1] .=  rrd::def("min", $RRDFILE[1], $DS[3], "AVERAGE");

if ($WARN[1] != "") {
	$def[1] .= "HRULE:$WARN[1]#FFFF00 ";
}
if ($CRIT[1] != "") {
	$def[1] .= "HRULE:$CRIT[1]#FF0000 ";
}

$def[1] .= rrd::line3("max", "#000000", "Maximum") ;
$def[1] .= rrd::line3("avg", "#0174DF", "Average") ;
$def[1] .= rrd::line3("min", "#B404AE", "Minimum") ;

?>
