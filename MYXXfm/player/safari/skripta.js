const RadioStanica = 'https://radiocnd.mms.mk/proxy/exyu/stream';
let audio = null;


function updatePageTitle(songName, artist) {
    const pageTitle = `${artist || 'Непознат Изведувач'} || ${songName || 'Непозната песна'} - Radio Network Kanal 77, the best radio station in Europe`;
    document.title = pageTitle;
}

    function fetchSongInfo() {
        console.log('fetchSongInfo()');
        fetch('https://exyu.kanal77.mk/api.php?url=https://radiocnd.mms.mk/proxy/exyu&streamtype=shoutcast&historic=true&next=false&t=1684398759392')
            .then(response => response.json())
            .then(data => {
                const currentSong = data.currentSong;
                const currentArtist = data.currentArtist;
                updateSongInfo(currentSong, currentArtist);
                fetchArtistImage(currentArtist);
            })
            .catch(error => console.error(error)); // Логирање во Console.log()
    }

    function updateSongInfo(songName, artist) {
        console.log('updateSongInfo()');
        document.getElementById('song-name').innerText = songName;
        document.getElementById('artist').innerText = artist;
    }

    const artistImageMap = {
        'JELENA': '951.jpg',
        'AERODROM': '218.jpg',
        'ALEKSANDAR MEZEK': '219.jpg',
        'ALEN SLAVICA': '222.jpg',
        'ALISA': '223.jpg',
        'ALKA VUJICA': '227.jpg',
        'AMBASADORI': '229.jpg',
        'ANIMATORI': '230.jpg',
        'ARSEN DEDIC': '232.jpg',
        'ATOMSKO SKLONISTE': '238.jpg',
        'AZRA': '244.jpg',
        'BABE': '247.jpg',
        'BAJAGA': '270.jpg',
        'BEBI DOL': '280.jpg',
        'BIJELO DUGME': '286.jpg',
        'BISERA VELETANLIC': '326.jpg',
        'BOBA STEFANOVIC': '956.jpg',
        'BOLERO': '950.jpg',
        'BOMBAJ STAMPA': '328.jpg',
        'BORIS NOVKOVIC': '329.jpg',
        'CRVENA JABUKA': '339.jpg',
        'DADO TOPIC': '361.jpg',
        'DALEKA OBALA': '363.jpg',
        'DANIJEL POPOVIC': '364.jpg',
        'DANIJELA MARTINOVIC': '365.jpg',
        'DARKO DOMIJAN': '367.jpg',
        'DEJAN CUKIC': '368.jpg',
        'DENIS DENIS': '371.jpg',
        'DINO DVORNIK': '377.jpg',
        'DINO MERLIN': '382.jpg',
        'DIVLJE JAGODE': '427.jpg',
        'DIVLJI ANDJELI': '432.jpg',
        'DJAVOLI': '433.jpg',
        'DJORDJE BALASEVIC': '439.jpg',
        'DORIAN GRAY': '466.jpg',
        'DORIS DRAGOVIC': '467.jpg',
        'DRAGAN STOJNIC': '949.jpg',
        'DRAZEN ZECIC': '478.jpg',
        'DRUGI NACIN': '479.jpg',
        'EKATERINA VELIKA': '481.jpg',
        'ELEKTRICNI ORGAZAM': '486.jpg',
        'ELVIRA RAHIC': '492.jpg',
        'FAMILIJA': '489.jpg',
        'FILM': '493.jpg',
        'FIT': '504.jpg',
        'FRANO LASIC': '507.jpg',
        'FRKA': '825.jpg',
        'GABI NOVAK': '509.jpg',
        'GALIJA': '552.jpg',
        'GENERACIJA 5': '560.jpg',
        'GIBONNI': '512.jpg',
        'GRUPA 220': '561.jpg',
        'HARI MATA HARI': '517.jpg',
        'HAUSTOR': '686.jpg',
        'IBRICA JUSIC': '961.jpg',
        'IDOLI': '562.jpg',
        'INDEXI': '647.jpg',
        'ITD BAND': '682.jpg',
        'IZOLDA': '781.jpg',
        'JADRANKA STOJAKOVIC': '678.jpg',
        'JAKARTA': '943.jpg',
        'JASNA ZLOKIC': '651.jpg',
        'JOSIPA LISAC': '774.jpg',
        'KALIOPI': '791.jpg',
        'KEMAL MONTENO': '793.jpg',
        'KERBER': '800.jpg',
        'KICO SLABINAC': '805.jpg',
        'KSENIJA ERKER': '962.jpg',
        'LAKI PINGVINI': '807.jpg',
        'LEB I SOL': '522.jpg',
        'LEO MARTIN': '529.jpg',
        'LETECI ODRED': '530.jpg',
        'MAGAZIN': '531.jpg',
        'MARINA PERAZIC': '638.jpg',
        'MASSIMO SAVIC': '576.jpg',
        'MERI CETINIC': '577.jpg',
        'METAK': '639.jpg',
        'MIKI JEVREMOVIC': '640.jpg',
        'MILADIN SOBIC': '634.jpg',
        'MINEA': '642.jpg',
        'MIRZINO JATO': '643.jpg',
        'MISO KOVAC': '543.jpg',
        'NEDA UKRADEN': '579.jpg',
        'NEKI TO VOLE VRUCE': '580.jpg',
        'NENO BELAN': '582.jpg',
        'NOVI FOSILI': '586.jpg',
        'OKTOBAR 1864': '601.jpg',
        'OLIVER DRAGOJEVIC': '605.jpg',
        'OLIVER MANDIC': '591.jpg',
        'OLIVERA KATARINA': '957.jpg',
        'OSMI PUTNIK': '952.jpg',
        'OSVAJACI': '658.jpg',
        'PARNI VALJAK': '663.jpg',
        'PEDJA D BOY': '965.jpg',
        'PILOTI': '697.jpg',
        'PLAVI ORKESTAR': '704.jpg',
        'POSLEDNJA IGRA LEPTIRA': '709.jpg',
        'PRLJAVO KAZALISTE': '723.jpg',
        'PRO ARTE': '713.jpg',
        'PSIHOMODO POP': '712.jpg',
        'REGATA': '741.jpg',
        'REGINA': '948.jpg',
        'RIBLJA CORBA': '742.jpg',
        'RIVA': '940.jpg',
        'SEVERINA': '955.jpg',
        'SLADJANA MILOSEVIC': '220.jpg',
        'SMAK': '786.jpg',
        'SRDJAN JUL': '788.jpg',
        'SREBRENA KRILA': '783.jpg',
        'STIJENE': '868.jpg',
        'SUNCANA STRANA ULICE': '790.jpg',
        'TAJCI': '826.jpg',
        'TEREZA KESOVIJA': '831.jpg',
        'TIFA': '870.jpg',
        'TIME': '823.jpg',
        'TONY MONTANO': '833.jpg',
        'TUTTI FRUTTI': '834.jpg',
        'U SKRIPCU': '893.jpg',
        'VAJTA': '836.jpg',
        'VALENTINO': '838.jpg',
        'VAN GOGH': '885.jpg',
        'VIDEOSEX': '840.jpg',
        'VIKTORIJA': '877.jpg',
        'VJESTICE': '843.jpg',
        'VLADO KALEMBER': '882.jpg',
        'XENIA': '841.jpg',
        'YU GRUPA': '842.jpg',
        'YU ROCK MISIJA': '850.jpg',
        'ZABRANJENO PUSENJE': '851.jpg',
        'ZANA': '844.jpg',
        'ZDRAVKO COLIC': '809.jpg',
        'ZELJKO BEBEK': '925.jpg',
        'ZLATKO PEJAKOVIC': '931.jpg',
        // сите изведувачи
      };
      
      function fetchArtistImage(artist) {
        console.log('fetchArtistImage()');
        const term = encodeURIComponent(artist);
        fetch(`https://itunes.apple.com/search?term=${term}`)
          .then(response => response.json())
          .then(data => {
            const results = data.results;
            if (results.length > 0) {
              const artistImage = results[0].artworkUrl100.replace('100x100bb', '512x512bb');
              updateRadioBackground(artistImage);
            } else {
              const localImageFileName = artistImageMap[artist.toUpperCase()];
              if (localImageFileName) {
                const localImagePath = `img/izveduvaci/${localImageFileName}`;
                updateRadioBackground(localImagePath);
              } else {
                // Handle case when no image is available
              }
            }
          })
          .catch(error => {
            console.error(error);
            const localImageFileName = artistImageMap[artist.toUpperCase()];
            if (localImageFileName) {
              const localImagePath = `img/izveduvaci/${localImageFileName}`;
              updateRadioBackground(localImagePath);
            } else {
              // Handle case when no image is available
            }
          });
      }
      
      

    function updateRadioBackground(imageUrl) {
        console.log('updateRadioBackground()');
        const radioImage = document.getElementById('radio-image');
        radioImage.style.backgroundImage = `url(${imageUrl})`;
    }

    function playRadio() {
        console.log('playRadio()');
        audio = new Audio(RadioStanica);
        audio.play();
        fetchSongInfo();
        document.getElementById('play-button').innerText = 'Stop';
        document.getElementById('play-button').classList.remove('btn-primary');
        document.getElementById('play-button').classList.add('btn-danger');
    }

    function stopRadio() {
        console.log('stopRadio()');
        if (audio) {
            audio.pause();
            audio = null;
            document.getElementById('play-button').innerText = 'Play';
            document.getElementById('play-button').classList.remove('btn-danger');
            document.getElementById('play-button').classList.add('btn-primary');
        }
    }

    document.getElementById('play-button').addEventListener('click', () => {
        if (audio && !audio.paused) {
            stopRadio();
        } else {
            playRadio();
        }
    });

    fetchSongInfo();
    setInterval(fetchSongInfo, 5000);
