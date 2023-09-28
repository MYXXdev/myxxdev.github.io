<?php
// траењето е злато - by GospoD
?>
<?php
error_reporting(0);
?>
<!DOCTYPE html>
<html class="no-js gt-ie8">
<html lang="en">
<head>
<meta charset="utf-8">
    <title>Канал 77 Стриминг Бекап</title>
    <link rel="shortcut icon" href="favicon.ico" type="image/x-icon">
    <link rel="icon" href="favicon.ico" type="image/x-icon">
    <meta name="viewport" content="width=1920">
    <meta name="viewport" content="minimum-scale=1.0, width=device-width, maximum-scale=1, user-scalable=no" />
    <meta id="viewport" name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Kanal 77 Radio Internet Streaming">
    <meta name="keywords" content="Kanal 77, Radio, Streaming, Слушај гласно, Slusaj glasno, Samo hitovi, Само хитови">
    <meta name="author" content="Trajce Gogov">
    <meta name="referrer" content="origin">
    <meta http-equiv="cache-control" content="no-store">
    <meta name="msapplication-TileColor" content="#0F0">
    <meta name="msapplication-navbutton-color" content="#0F0">
    <meta name="theme-color" content="#0F0">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="#0F0">
    <meta property="og:site_name" content="Kanal 77 Radio Internet Streaming">
    <meta property="og:locale" content="mk_MK">
    <meta property="og:title" content="Kanal 77 Radio Internet Streaming">
    <meta property="og:description" content="Kanal 77 Radio Internet Streaming">
    <meta property="og:type" content="PHP Bozja Sila Tools">
    <meta property="og:image" content="assets/images/slusajigledajsocijalni.png">
    <meta name="twitter:title" content="Kanal 77 Radio Streaming for iOS">
    <meta name="twitter:description" content="Kanal 77 Radio Streaming for iOS">
    <meta name="twitter:image" content="assets/images/slusajigledajsocijalni.png">

<!-- --/>
==============
 Style Sheets
==============
<!--Google Fonts-->
<link href='https://fonts.googleapis.com/css?family=Lato:300,400,700' rel='stylesheet' type='text/css'>
<link href='https://fonts.googleapis.com/css?family=Oswald:300,400,700' rel='stylesheet' type='text/css'>
<link rel="stylesheet" type="text/css" href="assets/css/bootstrap.css">
<link rel="stylesheet" type="text/css" href="assets/css/font-awesome.css">
<link rel="stylesheet" type="text/css" href="assets/css/h5p-font-awesome.css">
<link rel="stylesheet" type="text/css" href="assets/css/owl.theme.css">
<link rel="stylesheet" type="text/css" href="assets/css/owl.carousel.css">
<link rel="stylesheet" type="text/css" href="assets/css/owl.transitions.css">
<link rel="stylesheet" type="text/css" href="assets/css/jquery.vegas.css">
<link rel="stylesheet" type="text/css" href="assets/css/animations.css">
<link rel="stylesheet" type="text/css" href="assets/css/bigvideo.css">
<link rel="stylesheet" type="text/css" href="assets/css/jquery.mCustomScrollbar.css">
<link rel="stylesheet" href="assets/css/main.css">
<!-- lime_black -->
<link rel="stylesheet" type="text/css" href="assets/css/colors/lime_black.css">
<!--
<link rel="stylesheet" type="text/css" href="assets/css/colors/cyan.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/light_red.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/green_cyan.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/brown.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/magenta.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/blue_magenta.css">
<link rel="stylesheet" type="text/css" href="assets/css/colors/yellow.css">
-->
<script src="assets/js/modernizr-2.6.2-respond-1.1.0.js"></script>
</head>
<body data-spy="scroll" data-target="#sticktop" data-offset="70">
<!-- --/>
===========
 Лоадер
===========
<!-- -->
<div id="jSplash">
	<figure class="preload_logo">
	<img src="assets/images/mms-tv.png" alt="Канал 77 Радиовизија"/>
	</figure>
</div>

<div class="wide_layout box-wide">
    <!-- --/>
	===================
    Slider Images 
    ===================
	<!-- -->
    <ul class="vegas-slides hidden" data-speed="60000">
      <li>
	  <img data-fade='20000' src="assets/images/black_background.jpg" alt="Канал 77 Радиовизија" />
	  </li>
    </ul>

    <section id="section_1" class="banner hero_section">
      <div class="container">
        <div class="row">
          <div class="col-xs-12">
            <div class="hero_content animatedParent animateLoop">
              <h1 class="animated bounceInDown" style="background-color: #000; color: red;">Радио Канал 77<span class="primary_color"></span></h1>
              <h4 class="animated bounceInDown" style="color: white;">Само Хитови!</h4>
           </div>
          </div>
        </div>
      </div>
    <!-- --/>
	======================
    JPlayer (Audio Player)
    ======================
    <!-- -->
      <!--Do not edit this section Unless you have to modify HTML structure of Playlist-->
      <div class="rock_player pre_sticky">
      <div class="sticky_player" data-sticky="true">
        <div class="play_list">
          <div class="list_scroll">
            <div class="container ">
              <ul class="music_widget player_data">
                <li class="music_row_header">
                  <div class="column_one"></div>
                 <!-- <div class="column_two"> &nbsp;<!-- NO HEADER FOR PICTURE COLUMN --/></div> -->
				  <div class="column_two"></div>
                  <div class="column_three"></div>
                  <div class="column_four"></div>
                  <div class="column_six"></div>
				  <div class="column_five"> &nbsp;&nbsp;</div>
                  <div class="column_eight"> &nbsp;<!-- NO HEADER FOR BTN COLUMN --> 
                  </div>
                </li>
				<!-- START PLAYER COLUMN -->
                <li class="music_row">
                  <div class="column_one track_index"></div>
                  <div class="column_two track_thumb"></div>
                  <div class="column_three track_title"></div>
                  <div class="column_four track_genre"></div>
                  <div class="column_five track_composer"></div>
                  <div class="column_six track_length"></div>
                  <div class="column_seven">
				  <a class="play_it" href="#">
				  <span class="fa fa-play"></span>
				  </a>
				  <a href="#">
				  <span class="fa fa-plus"></span>
				  </a>
				  </div>
                  <div class="column_eight">
				  </div>
                </li>
				<!-- END PLAYER COLUMN  -->
                <!--music row-->
              </ul>
              <!--music_widget--> 
            </div>
            <!--container--> 
          </div>
        </div>
        <!-- --/>
		=========================================================
        Edit or Modify Playist content in the following Hypertext
        =========================================================
		<!-- PLAYLIST TABLE -->
        <div class="jp-playlist hidden"> 
          <!-- Форматирање -->
          <ul class="playlist-files">
            <!-- Радио 1 -->
            <li
                   data-thumb="assets/images/32x32px-logo-kanal77.png"
                   data-title="Радио Канал 77"
                   data-artist="Live"
                   data-length="Радио "
				           data-mp3="https://radiocnd.mms.mk/proxy/web/stream">
			      </li>
          </ul>
          <!--Playlist ends-->
        </div>
        <div class="container player_wrapper">
          <div class="row">
            <div id="player-instance" class="jp-jplayer" ></div>
            <div class="jp-title audio-title" title="Playing Now">Playing Now</div>
            <div class="rock_controls controls">
              <div  class="fa fa-play jp-play"></div>
              <div  class="fa fa-pause jp-pause"></div>
            </div>
            <!--controls-->
            <!--audio-progress-->
            <div class="jp-volume">
              <ul>
                <li class="active">
				        <a href="#1"></a>
				        </li>
                <li class="active">
        				<a href="#2"></a>
        				</li>
                <li class="active">
				        <a href="#3"></a>
				        </li>
                <li class="active">
				        <a href="#4"></a>
				        </li>
                <li>
				        <a href= "#5"></a>
				        </li>
              </ul>
            </div>
            <a href="#6" class="playlist_expander fa fa-bars" title="Open Radio List"></a>
			</div>
        </div>
      </div>
	  </div>
    </section>
    <!--//banner--> 
    </div>
<!-- --/>
===========
JS SCRIPTS
===========
<!-- -->
<script src="assets/js/jquery-1.11.0.js"></script> 
<script src="assets/js/jpreloader.js"></script>
<script src="assets/js/jquery.mousewheel.js"></script> 
<script src="assets/js/bootstrap.js"></script> 
<script src="assets/js/jquery_easing.js"></script> 
<script src="assets/js/jquery.stellar.js"></script>
<script src="assets/js/owl.carousel.js"></script> 
<script src="assets/js/jquery.carouFredSel.js"></script> 
<script src="assets/js/tweetie.js"></script> 
<script src="assets/js/jquery.sticky.js"></script> 
<script src="assets/js/jquery.jplayer.js"></script> 
<script src="assets/js/jplayer.playlist.js"></script> 
<script src="assets/js/jquery.vegas.js"></script> 
<script src="assets/js/css3-animate-it.js"></script> 
<script src="assets/js/jquery.fractionslider.js"></script> 
<script src="assets/js/jquery.mCustomScrollbar.js"></script> 
<script src="assets/js/jquery.waitforimages.js"></script>
<script src="assets/js/video.js"></script>
<script src="assets/js/bigvideo.js"></script>
<script src="assets/js/main.js"></script>  
<script src="assets/js/script.js"></script>
<!-- Global site tag (gtag.js) - Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-4935TK7Z4D"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-4935TK7Z4D');
</script>
<script>
// LOADING BAR AT STARTUP
$('body').jpreLoader({
		splashID: "#jSplash",
		loaderVPos: '50%',
		autoClose: true,
});
/*
==================================
Google Track Code - Стави го тука
==================================
*/
</script>

<!-- --/>
/ICECAST_EXAMPLES
MOUNTPOINT SETTINGS
DOC: https://icecast.org/docs/icecast-2.4.1/basic-setup.html
https://icecast.org/docs/icecast-2.4.0/config-file.html
STREAM TITLE OUTPUT
<!-- --/>

<!-- MY PORT 8888 --/>
<script>
var timeout = 5;
function getStats(){
  $.ajax({
	//url: "http://icestats_server_host:port/status-json.xsl?mount=/stream.mp3",
	//url: "http://192.168.1.1:8888/status-json.xsl?mount=/dance.mp3", // EXAMPLE
    success: function( response ) {
    $('#song-title').text(response.icestats.source.title)
    }   
  });
}

getStats();
setInterval(getStats, timeout * 10000);
</script>
</p>
<!-- STREAM TITLE OUTPUT -->

</body>
</html>
