jQuery(function($){
    "use strict";
	
	
	/*============
	1-Hero Header
	2-Navigation
	3-Video Banner
	4-Gallery
	5-Fraction Slider
	6-Parallax
	7-Carousel fredsel
	8-Owl Slider
	9-Vegas Slider
	10-Tweet
	11-JPlayer
	12- Contact Form
	==============*/
	
	
	
	var isStickyPlayer=$(".sticky_player").attr('data-sticky'),
		isStickyNav=$("#sticktop").attr('data-sticky'),
		naviheight=$("#sticktop").height(),
		playerHeight=$(".sticky_player").height(),
		navTopSpace=0,NavOffset=0;
		var $winHeight=$(window).height(),
		$winWidth=$(window).width();
	/*=======================================
	1-Hero Header
	=======================================*/
		
	$(window).on('resize', function(){
		$winHeight=$(window).height();
		$winWidth=$(window).width();
		
		$('.hero_section').css('height',$winHeight+'px');
		var $hero_height=$('.hero_section').height(), 
			$hero_content_height=$('.hero_content').height();
		
		if($hero_height<$hero_content_height ){$('.hero_section').css('height',$hero_content_height+70+'px');}
		$('.hero_section').css('padding-top',($hero_height/2)-($hero_content_height/2)+'px');
		
	}).resize();
		
	$(".list_scroll").mCustomScrollbar({advanced: {updateOnContentResize: true},});
		
	/*=======================================
	2-Navigation
	=======================================*/
	
	if(isStickyNav!="false"){NavOffset=naviheight + 10;}
	if(isStickyPlayer!="false"){NavOffset=playerHeight+10;}
	if(isStickyNav!="false" && isStickyPlayer!="false"){NavOffset=naviheight+playerHeight+10;}	
	$('body').attr('data-offset',NavOffset+10);
	
    $(".navbar-nav a[href^='#'],.ScrollTo,.btn-scroll").click(function (e) {
		e.preventDefault();
        $('html, body').stop().animate({scrollTop: $($.attr(this, 'href')).offset().top - NavOffset}, 1000,"swing");
    });
	
	
	if($winWidth>700){
	  if($(".sticky_player").attr('data-sticky')!="false"){navTopSpace=playerHeight;}
	  if(isStickyNav!="false"){
		  $("#sticktop").sticky({topSpacing:navTopSpace});}  
	  if($(".sticky_player").attr('data-sticky')!="false"){
		  $(".sticky_player").sticky({topSpacing: 0});
	  }
	  $('#sticktop').on('sticky-start', function() {
		  if($(".sticky_player").attr('data-sticky')!="false")
		  $('.rock_player').removeClass('pre_sticky');
	  });
	  $('#sticktop').on('sticky-end', function() {
		  if($(".sticky_player").attr('data-sticky')!="false")
		  $('.rock_player').addClass('pre_sticky');
	  });  
	}
	
	/*=======================================
	3-Video Banner
	=======================================*/
	if($('.video-banner').length!=0){
		var BV = new $.BigVideo({useFlashForFirefox:false});
   		BV.init();
		BV.getPlayer().poster('assets/video/video-poster.jpg');
		BV.show('assets/video/demo.mp4',{doLoop:true});
		
		$('.video-load').show();
		BV.getPlayer().on('seeking',function(){
			$('.video-load').hide();
			$('.video-pause').show();
			$('.video-play').hide();
			console.log("seeking");
		});
		
		BV.getPlayer().on('play',function(){
			$('.video-load').hide();
			$('.video-pause').show();
			$('.video-play').hide();
		});
		BV.getPlayer().on('ended',function(){
			$('.video-load').hide();
			$('.video-play').show();
			$('.video-pause').hide();
		});
		BV.getPlayer().on('loadstart',function(){
			$('.video-load').show();
			$('.video-pause').hide();
			$('.video-play').hide();
		}); 
		BV.getPlayer().on('loadeddata',function(){
			$('.video-load').hide();
			$('.video-pause').show();
			$('.video-play').hide();
			console.log("data loaded for curent time");
		});
		$('.video-pause').click(function(){
			BV.getPlayer().pause();
			$('.video-load').hide();
			$('.video-pause').hide();
			$('.video-play').show();
		});
		$('.video-play').click(function(){
			BV.getPlayer().play();
			$('.video-play').hide();
			$('.video-pause').show();
		});
	}
	
	/*=======================================
	4-Gallery
	=======================================*/
	
	$('.sliderGallery,.trigger_slider').click(function(e){
		e.preventDefault();
        var $this=$(this), 
            p = $this.parents(".modal"), 
            gallayoutOption = p.find('.gallayoutOption'),
            gal_list =p.find('.gal_list'),
            socialShare = p.find('.social_share');
        
		gallayoutOption.children("li").removeClass('active');
		$this.parent('li').addClass('active');
        
		gal_list.children("li").each(function() {
			$(this).removeClass('trigger_slider').addClass('gallery-item');
        });
        
		gal_list.addClass('owl-carousel owl-gallery');
		 gal_list.owlCarousel({
			slideSpeed : 1000,
			pagination : false,
			singleItem:true,
			navigation : true,
		 });
		 socialShare.slideDown();
	});
	
	$('.gridGallery').on('click', function (e) {
        e.preventDefault();
        var $this=$(this), 
            p = $this.parents(".modal"),
            gallayoutOption = p.find('.gallayoutOption'),
            socialShare = p.find('.social_share'),
            gal_list =p.find('.gal_list'),
            owlGal = p.find(".owl-gallery");
        
		gallayoutOption.children("li").removeClass('active');
		$this.parent('li').addClass('active');
        
        socialShare.slideUp();
        
		if(owlGal.length){
			owlGal.data('owlCarousel').destroy();
			gal_list.children("li").each(function() {
				$(this).addClass('trigger_slider').removeClass('gallery-item');
			});
			gal_list.removeClass('owl-carousel owl-gallery');
		}
	});
	
	/*=======================================
	5-Fraction Slider
	=======================================*/
    
	$('.fractionSlide').fractionSlider({
        dimensions: '1970,1000',
        responsive: true,
        backgroundAnimation: true,
        slideTransitionSpeed: 200,
        pager: true,
        startCallback: function () {
            $('.fractionSlide .slide').show();
        }
    });
    
	/*=======================================
	6-Parallax
	=======================================*/
    
	  $.stellar({
		horizontalScrolling: false,
		verticalOffset: 0,
		responsive:true,
	  });

	/*=======================================
	7-Carousel fredsel
	=======================================*/
    
	$('.news_carousel').waitForImages(function() {
		$('.news_carousel').carouFredSel({
			width: "100%",
			circular: false,
			infinite: false,
			auto: false,
			align: "centre",
			
			scroll: {
				items: 1,easing: "linear"
			},
			prev: { button: "#news-prev", key: "left"},
			next: {button: "#news-next",key: "right"},
		});
	});
    
	$('.members_carousel').waitForImages(function() {
		$('.members_carousel').carouFredSel({
			width: "100%",
			circular: false,
			infinite: false,
			auto: false,
			align: false,
			scroll: {
				items: 1,easing: "linear"
			},
			prev: { button: "#member-prev", key: "left"},
			next: {button: "#member-next",key: "right"},
		});
	});
    
	/*==========================================
	8-Owl Slider
	=======================================*/
    
	$(".testimonial_quotes").owlCarousel({
		slideSpeed : 1000,
      	paginationSpeed : 500,
      	singleItem:true,
	  	navigation : false,
		transitionStyle:"backSlide",
		afterAction:function(){$(window).trigger("resize");},
	 });
	 
	 /*============================
	9-Vegas Slider
	============================*/
	
	if($('.vegas-slides').length){
		var vegas_BG_imgs = [],
		$vegas_img = $('.vegas-slides li img'),
		vegas_slide_length= $('.vegas-slides li').length;
		
		for (var i=0; i < vegas_slide_length; i++) {
			var new_vegas_img = {};
			new_vegas_img['src'] = $vegas_img.eq(i).attr('src');
			new_vegas_img['fade'] =$vegas_img.eq(i).attr('data-fade');
			vegas_BG_imgs.push(new_vegas_img);
		}
		
		var slideSpeed= $('.vegas-slides').data("speed");
		$.vegas('slideshow', {
			delay:slideSpeed,
			backgrounds:vegas_BG_imgs,
		});
		$('.vegas-controls a').click(function(e){
			e.preventDefault();
			var $parent=$(this).parent('li');
			if(!$parent.hasClass('active')){
				$('.vegas-controls li').removeClass('active');
				$parent.addClass('active');
				$.vegas('jump', $parent.index());
			}
		});
		$('body').bind('vegaswalk',
		function(e, bg, step) {
			$('.vegas-controls li').removeClass('active');
			$('.vegas-controls li').eq(step).addClass('active');
		});
	}
	
	if($winWidth<760){
		$.vegas('pause');
	}
	
	reanimate();
    function reanimate() {
        $('.ScrollTo > i').animate({top:0}, 1000).animate({top: 20},1000,function(){setTimeout(reanimate, 100);});
    }
	
	/*========================================
	10-Tweet
	===========================================*/
	if($('.tweet').length!=0){
		 $('.tweet').twittie({
			username:'envato',
			dateFormat: '%b. %d, %Y',
			template: '{{tweet}} <time class="date">{{date}}</time>',
			count: 3,
			apiPath:"assets/php/tweet_api/tweet.php",
		},function(){
			$(".tweet ul").addClass("tweet_slider owl-carousel owl-theme");
			$(".tweet_slider").owlCarousel({
				slideSpeed : 1000,
				paginationSpeed : 500,
				singleItem:true,
				navigation : false,
				autoHeight : true,
			 });
		});
	}
	
	/*==========================================
	11-JPlayer
	=======================================*/
	
	
	$('.playlist_expander').click(function(e){
		e.preventDefault();
		$('.play_list').slideToggle();
	});
	 $("#player-instance").jPlayer({
        cssSelectorAncestor: ".rock_player", // Remove the ancestor css selector clause
    });
	if($('.playlist-files').length){
		var playlist_items = [],
		$playlist_audio=$('.playlist-files li'),
		$list_content=$('.player_data li'),
		playlist_items_length= $playlist_audio.length;
		
		for (var i=0; i < playlist_items_length; i++) {
			var  new_playlist_item = {};
			new_playlist_item['title'] = $playlist_audio.eq(i).attr('data-title');
			new_playlist_item['artist'] = $playlist_audio.eq(i).attr('data-artist');
			new_playlist_item['mp3'] = $playlist_audio.eq(i).attr('data-mp3');
			playlist_items.push(new_playlist_item);
			
			$list_content.eq(i+1).children('.track_index').html(i+1);
			$list_content.eq(i+1).children('.track_thumb').html('<img src='+$playlist_audio.eq(i).attr('data-thumb')+' alt="track Thumb" />');
			$list_content.eq(i+1).children('.track_title').html($playlist_audio.eq(i).attr('data-title'));
			$list_content.eq(i+1).children('.track_genre').html($playlist_audio.eq(i).attr('data-genre'));
			$list_content.eq(i+1).children('.track_composer').html($playlist_audio.eq(i).attr('data-artist'));
			$list_content.eq(i+1).children('.track_length').html($playlist_audio.eq(i).attr('data-length'));
			$list_content.eq(i+1).find('.btn_watch_video').attr('href',$playlist_audio.eq(i).attr('data-video'));
			$list_content.eq(i+1).find('.itunesLink').attr('href',$playlist_audio.eq(i).attr('data-itunes'));
		}
		
		var werock = new jPlayerPlaylist({
			jPlayer: "#player-instance",
			cssSelectorAncestor: "",
		},playlist_items ,
			{playlistOptions: {autoPlay: false}},
		{
			swfPath: "assets/jPlayer/jquery.jplayer.swf",
			supplied: "mp3",
		});
		$('.play_it').click(function(e){
			e.preventDefault();
			werock.play($(this).parents('li').index()-1);
		});
		$('.audio-title').html(werock.playlist[0].title);
		$("#player-instance").bind($.jPlayer.event.play, function (event) {
			var current = werock.current,
				playlist = werock.playlist;
			jQuery.each(playlist, function (index, obj) {
				if (index == current) {
					$('.audio-title').html(obj.title);
				}
			});
		});
		$("#player-instance").jPlayer("volume", '0.8');
		$('.jp-volume li a').click(function(e){
			e.preventDefault();
			$('.jp-volume li').removeClass('active');
			 $("#player-instance").jPlayer("volume", ($(this).parent().index()+1)/10*2);
			for(var i=0;i<=$(this).parent().index();i++){
				$('.jp-volume li').eq(i).addClass('active');
			}
		});
	}

	function IsEmail(email) {
        var regex = /^([a-zA-Z0-9_\.\-\+])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
        return regex.test(email);
    }

    if($("#contactform").length!=0){
        $("#contactform").submit(function (e) {
            e.preventDefault();
            var name = $("#name").val(),
            email = $("#email").val(),
            subject = $("#subject").val(),
            message = $("#message").val(),
            dataString = 'name=' + name + '&email=' + email+ '&subject=' + subject + '&message=' + message;

            if (name === '' || !IsEmail(email) || message === '') {
                $('#valid-issue').html('Please Provide Valid Information').slideDown();
            } else {
                $.ajax({
                    type: "POST",
                    url: "assets/php/submit.php",
                    data: dataString,
                    success: function () {
                        $('#contactform').slideUp();
                        $('#valid-issue').html('Your message has been sent,<BR> We will contact you back with in next 24 hours.').show();
                    }
                });
            }
        });
    }

    /*==========================
    Ajax Expander
    ==========================*/
    
    $('.triggerTrack').click(function(e){
        e.preventDefault();
        $('.trackLoading').show();
        console.log($('#tracksAjax').height());
        var $this = $(this),href = $this.attr('href'),key=$this.attr("data-number");
        if(!href==='#'){ return}
        $.ajax({
            url:  href ,
            dataType: 'html',
            success: function(data) {
                var targetPageContent = $('<div />').html(data).find('.pageContentArea #album'+key);
                $('#tracksAjax').html(targetPageContent).slideDown();
                $('.closeTrackAjax').show();
                $('.trackLoading').hide();
                $('html, body').stop().animate({scrollTop: $("#tracksAjaxWrapper").offset().top - NavOffset}, 1000,"swing");
            },
            error: function (request, status, error) {
                alert(request.responseText);
                $('.trackLoading').hide();
            }

        });
     });

    $('.closeTrackAjax').click(function(e){
        e.preventDefault();
        $('html, body').stop().animate({scrollTop: $($(this).attr('href')).offset().top - NavOffset}, 500,"swing");
        $(this).hide();
        $('#tracksAjax').slideUp();
    });

    $('.closeNewsAjax').click(function(e){
        e.preventDefault();
        $('html, body').stop().animate({scrollTop: $($(this).attr('href')).offset().top - NavOffset}, 500,"swing");
        $(this).hide();
        $('#newsAjax').slideUp();
    });

    $('.triggerNews').click(function(e){
        e.preventDefault();
        $('.trackLoading').show();
        var $this = $(this),href = $this.attr('href'),key=$this.attr("data-number");
        if(!href==='#'){ return}
        $.ajax({
            url:  href ,
            dataType: 'html',
            success: function(data) {
                var targetPageContent = $('<div />').html(data).find('.pageContentArea #xv-news'+key);
                $('#newsAjax').html(targetPageContent).slideDown();
                $('.trackLoading').hide();
                $('.closeNewsAjax').show();
                $('html, body').stop().animate({scrollTop: $("#newsAjaxWrapper").offset().top - NavOffset}, 1000,"swing");

            },
            error: function (request, status, error) {
                alert(request.responseText);
                $('.trackLoading').hide();
            }

        });
     });
		
	/*==========================
    Connect Tabs
    ==========================*/
    
    $("body").on("click",".tab-link",function(e){
        e.preventDefault();
        var $this = $(this),
            tabId = $this.data("tab");
        $(".tab-link").removeClass("active");
        $this.addClass("active");
        $(".tab-content").removeClass("active");
        $(".tab-content#"+tabId).addClass("active");
    });
		
});

