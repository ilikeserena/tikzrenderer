<html>
<head>
	<title>PHP TikZ test</title>
	<script type="text/javascript" src="clientscript/jquery/jquery-1.6.4.min.js"></script>
</head>
<body>
  <p>rendersvg:<br/><img id="rendersvg" src=""></img></p>
  <p>tikz:<br/><textarea id="tikz" name="tikz" cols="120" rows="16">
\begin{tikzpicture}
  \begin{axis}
    \addplot coordinates {(0,1) (0.5,1) (1,1.2)}; 
  \end{axis} 
\end{tikzpicture}
  </textarea></p>

<script>

// Trigger rendering only when user is done typing, say after 1 second
var typingTimer;                //timer identifier
var doneTypingInterval = 200;  //time in ms, 1 second for example

// On keyup, start the countdown
$('#tikz').keyup(function () {
  clearTimeout(typingTimer);
  typingTimer = setTimeout(doneTyping, doneTypingInterval);
});

// On keydown, clear the countdown 
$('#tikz').keydown(function () {
  clearTimeout(typingTimer);
});

// User is "done typing", make a rendering request
function doneTyping () {
	//do something
	console.log('doneTyping->renderrequest');
	var tikzUri = $('#tikz').val();
	tikzUri = encodeURIComponent(tikzUri);
	$('#rendersvg').attr('src', 'http://ec2-35-164-73-255.us-west-2.compute.amazonaws.com/cgi-bin/tikzrendersvg.pl?context=live&tikz=' + tikzUri);
}

{
	console.log('initial renderrequest');
	var tikzUri = $('#tikz').val();
	tikzUri = encodeURIComponent(tikzUri);
	$('#rendersvg').attr('src', 'http://ec2-35-164-73-255.us-west-2.compute.amazonaws.com/cgi-bin/tikzrendersvg.pl?context=live&tikz=' + tikzUri);
}


$('#rendersvg').each(function(){
	if (this.complete || /*for IE 10-*/ $(this).height() > 0) {
		console.log('complete');
	}
});
$('#rendersvg').each(function(){
	$(this).load(function(){
		console.log('loaded');
	});
});

</script>
  
</body>
</html>

<!--
<?php
	$match = '\begin{tikzpicture}
  \begin{axis}
    \addplot coordinates {(0,1) (0.5,1) (1,1.2)}; 
  \end{axis} 
\end{tikzpicture}';

	$tikzForMd5 = preg_replace("/[\s\r\n]+/m", " ", $match);
	$tikzForMd5 = preg_replace("/^\s*(.*?)\s*$/", "$1", $tikzForMd5);
	$tikzMd5 = md5($tikzForMd5);
	$clientsvgfile = "/tikz/$tikzMd5.svg";
	$serversvgfile = $_SERVER['DOCUMENT_ROOT'] . $clientsvgfile;

	print "<img src=$clientsvgfile></img><br />\n";
	print "$serversvgfile<br />\n";
	print "$clientsvgfile<br />\n";

	if (!file_exists($serversvgfile))
	{
		$tikzUri = urlencode($tikz);
		$content = file_get_contents("http://ec2-35-164-73-255.us-west-2.compute.amazonaws.com/cgi-bin/tikzrendersvg.pl?tikz=$tikzUri");
		file_put_contents($serversvgfile, $response);
	}
?>
-->
