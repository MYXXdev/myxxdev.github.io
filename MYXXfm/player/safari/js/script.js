/*
|--------------------------------------------------------------------------
| Конфигурација на сктирптата - Trajce Gogov
|--------------------------------------------------------------------------
|
| Треба да знаеш што работиш тука за да правеш промени
|
*/

window.addEventListener("load", function() {
    var page = new Page();
    page.changeTitlePage();
    page.setVolume();

    var player = new Player();
    
    // Add a click event listener to trigger the play() function
    document.addEventListener("click", function() {
        player.play();
    }, { once: true }); // Ensure the event listener is removed after the first click

    getStreamingData();
    // Value in milliseconds
    setInterval(function () {
        getStreamingData();
    }, 4000);

    var coverArt = document.getElementsByClassName('cover-album')[0];
    coverArt.style.height = coverArt.offsetWidth + 'px';
});

function Page() {
    this.changeTitlePage = function (title = RADIO_NAME) {
        document.title = title;
    };

    this.refreshCurrentSong = function (song, artist) {
        var currentSong = document.getElementById('currentSong');
        var currentArtist = document.getElementById('currentArtist');

        if (song !== currentSong.innerHTML) {
            currentSong.className = 'animated flipInY text-uppercase';
            currentSong.innerHTML = song;

            currentArtist.className = 'animated flipInY text-capitalize';
            currentArtist.innerHTML = artist;
            document.getElementById('lyricsSong').innerHTML = song + ' - ' + artist;
            setTimeout(function () {    
                currentSong.className = 'text-uppercase';    
                currentArtist.className = 'text-uppercase';
            }, 2000);}
        }

    this.refreshHistoric = function (info, n) {
        var $historicDiv = document.querySelectorAll('#historicSong article');
        var $songName = document.querySelectorAll('#historicSong article .music-info .song');
        var $artistName = document.querySelectorAll('#historicSong article .music-info .artist');

        var urlCoverArt = DEFAULT_COVER_ART;

        // Дефинирање на позадини за песни - горе
        const FRATELLO = "img/izveduvaci/212.jpg";
        const STAVI_PRAVU_STVAR = 'img/izveduvaci/213.jpg';
        const STO_SI_U_KAVU_STAVILA = 'img/izveduvaci/214.jpg';
        const OBICNA_LJUBAVNA_PJESMA = 'img/izveduvaci/215.jpg';
        const A_STA_DA_RADIM = 'img/izveduvaci/216.jpg';
        const DIGNI_ME_VISOKO = 'img/izveduvaci/217.jpg';
        const OTKAZAN_LET = 'img/izveduvaci/218.jpg';
        const LJUBAV_PREKO_ZICE = 'img/izveduvaci/219.jpg';
        const MIKI_MIKI = 'img/izveduvaci/220.jpg';
        const DAO_SAM_TI_DUSU = 'img/izveduvaci/221.jpg';
        const S_TOBOM_NASAO_SAM_SRECU = 'img/izveduvaci/222.jpg';
        const KESTENI = 'img/izveduvaci/223.jpg';
        const POSLE_9_GODINA = 'img/izveduvaci/224.jpg';
        const SANJA = 'img/izveduvaci/225.jpg';
        const EJ_STA_MI_RADIS = 'img/izveduvaci/226.jpg';
        const NEK_TI_JUTRO_MIRISE_NA_MENE = 'img/izveduvaci/227.jpg';
        const DOJDJI_U_5_DO_5 = 'img/izveduvaci/228.jpg';
        const ZEMLJO_MOJA_FT_ISMETA_KRAVAC = 'img/izveduvaci/229.jpg';
        const ANDJELI_NAS_ZOVU_DA_IM_SKINEMO_KRILA = 'img/izveduvaci/230.jpg';
        const O_MLADOSTI = 'img/izveduvaci/231.jpg';
        const SVE_STO_ZNAS_O_MENI = 'img/izveduvaci/232.jpg';
        const DEVOJKA_IZ_MOGA_KRAJA = 'img/izveduvaci/233.jpg';
        const PROLJECE_BEZ_TEBE = 'img/izveduvaci/234.jpg';
        const ZAGRLI_ME1 = 'img/izveduvaci/235.jpg';
        const DEVOJKA_BROJ_8 = 'img/izveduvaci/236.jpg';
        const PAKLENI_VOZACI = 'img/izveduvaci/237.jpg';
        const ZA_LJUBAV_TREBA_IMAT_DUSU = 'img/izveduvaci/238.jpg';
        const VOLJELA_ME_NIJE_NI_JEDNA = 'img/izveduvaci/239.jpg';
        const USNE_VRELE_VISNJE = 'img/izveduvaci/240.jpg';
        const AKO_ZNAS_BILO_STA = 'img/izveduvaci/241.jpg';
        const BALKAN = 'img/izveduvaci/242.jpg';
        const GRACIJA = 'img/izveduvaci/243.jpg';
        const MARINA = 'img/izveduvaci/244.jpg';
        const LJEPE_ZENE_PROLAZE_KROZ_GRAD = 'img/izveduvaci/245.jpg';
        const NOC_BEZ_SNA = 'img/izveduvaci/246.jpg';
        const DA_TE_VIDIM_GOLU = 'img/izveduvaci/247.jpg';
        const SAMO_NAM_JE_LJUBAV_POTREBNA = 'img/izveduvaci/248.jpg';
        const PLAVI_SAFIRU = 'img/izveduvaci/249.jpg';
        const OD_KAD_TEBE_VOLIM = 'img/izveduvaci/250.jpg';
        const VERUJEM_NE_VERUJEM = 'img/izveduvaci/251.jpg';
        const GODINE_PROLAZE = 'img/izveduvaci/252.jpg';
        const TISINA = 'img/izveduvaci/253.jpg';
        const RUSKI_VOZ = 'img/izveduvaci/254.jpg';
        const VESELA_PESMA = 'img/izveduvaci/255.jpg';
        const ZIVOT_JE_NEKAD_SIV_NEKAD_ZUT = 'img/izveduvaci/256.jpg';
        const GORE_DOLE = 'img/izveduvaci/257.jpg';
        const TI_SE_LJUBIS = 'img/izveduvaci/258.jpg';
        const SA_DRUGE_STRANE = 'img/izveduvaci/259.jpg';
        const ZAZMURI = 'img/izveduvaci/260.jpg';
        const DO_BEOGRADA = 'img/izveduvaci/261.jpg';
        const VIDI_STA_SAM_TI_URADIO_OD_PESME_MAMA = 'img/izveduvaci/262.jpg';
        const SARENE_PILULE = 'img/izveduvaci/264.jpg';
        const VEK = 'img/izveduvaci/265.jpg';
        const TAMARA = 'img/izveduvaci/266.jpg';
        const POLJUBI_ME = 'img/izveduvaci/267.jpg';
        const LEPA_JANJA_RIBAREVA_KCI = 'img/izveduvaci/268.jpg';
        const ZMAJ_OD_NOCAJA = 'img/izveduvaci/269.jpg';
        const MUZIKA_NA_STRUJU = 'img/izveduvaci/270.jpg';
        const OVO_JE_BALKAN = 'img/izveduvaci/271.jpg';
        const JOS_TE_VOLIM1 = 'img/izveduvaci/272.jpg';
        const NA_VRHOVIMA_PRSTIJU = 'img/izveduvaci/273.jpg';
        const KAD_HODAS = 'img/izveduvaci/274.jpg';
        const MOJI_SU_DRUGOVI = 'img/izveduvaci/275.jpg';
        const GDE_SI = 'img/izveduvaci/276.jpg';
        const BAM_BAM_BAM = 'img/izveduvaci/277.jpg';
        const NEKA_SVEMIR_CUJE_NEMIR = 'img/izveduvaci/278.jpg';
        const JEDINO_TO_SE_ZOVE_LJUBAV = 'img/izveduvaci/279.jpg';
        const KRV_SRECA_SUZE_I_ZNOJ = 'img/izveduvaci/280.jpg';
        const RUDI = 'img/izveduvaci/281.jpg';
        const BRA_ZIL = 'img/izveduvaci/282.jpg';
        const HAJDE_DA_UZMEMO_NEKI_DOBAR_AUTO = 'img/izveduvaci/283.jpg';
        const BADEMI_I_SO_FT_BAJAGA = 'img/izveduvaci/284.jpg';
        const DA_PRICAMO_O_LJUBAVI = 'img/izveduvaci/285.jpg';
        const IPAK_POZELIM_NEKO_PISMO = 'img/izveduvaci/286.jpg';
        const BITANGA_I_PRINCEZA = 'img/izveduvaci/287.jpg';
        const SVE_CE_TO_MILA_MOJA_PREKRITI_RUZMARIN = 'img/izveduvaci/288.jpg';
        const NOCAS_JE_KO_LUBENICA = 'img/izveduvaci/289.jpg';
        const PLJUNI_I_ZAPEVAJ_MOJA_JUGOSLAVIJO = 'img/izveduvaci/290.jpg';
        const A_I_TI_ME_IZNEVJERI = 'img/izveduvaci/291.jpg';
        const RUZICA_SI_BILA = 'img/izveduvaci/292.jpg';
        const HAJDEMO_U_PLANINE = 'img/izveduvaci/293.jpg';
        const JER_KAD_OSTARIS = 'img/izveduvaci/294.jpg';
        const LAZES_ZLATO = 'img/izveduvaci/295.jpg';
        const ZA_ESMU = 'img/izveduvaci/296.jpg';
        const LIPE_CVATU = 'img/izveduvaci/297.jpg';
        const PADAJU_ZVEZDE = 'img/izveduvaci/298.jpg';
        const DA_TE_BOGDO_NEVOLIM = 'img/izveduvaci/299.jpg';
        const MENI_SE_NESPAVA = 'img/izveduvaci/300.jpg';
        const AKO_MOZES_ZABORAVI = 'img/izveduvaci/301.jpg';
        const U_VREME_OTKAZANIH_LETOVA = 'img/izveduvaci/302.jpg';
        const DOZIVJETI_STOTU = 'img/izveduvaci/303.jpg';
        const ZAZMURI_I_BROJ_DO_100 = 'img/izveduvaci/304.jpg';
        const PRISTAO_SAM_BICU_SVE_STO_HOCE = 'img/izveduvaci/305.jpg';
        const HA_HA_HA_SVI_MARS_NA_PLJES = 'img/izveduvaci/306.jpg';
        const KAD_BI_BIO_BIJELO_DUGME = 'img/izveduvaci/307.jpg';
        const SELMA = 'img/izveduvaci/308.jpg';
        const IMA_NEKA_TAJNA_VEZA = 'img/izveduvaci/309.jpg';
        const DA_SAM_PEKAR = 'img/izveduvaci/310.jpg';
        const NE_SPAVAJ_MALA_MOJA_MUZIKA_DOK_SVIRA = 'img/izveduvaci/311.jpg';
        const AKO_IMA_BOGA = 'img/izveduvaci/312.jpg';
        const NAPILE_SE_ULICE = 'img/izveduvaci/313.jpg';
        const STA_IMA_NOVO = 'img/izveduvaci/314.jpg';
        const NAKON_SVIH_OVIH_GODINA = 'img/izveduvaci/315.jpg';
        const CIRIBIRIBELA = 'img/izveduvaci/316.jpg';
        const DJURDJEVDAN = 'img/izveduvaci/317.jpg';
        const EVO_ZAKLECU_SE = 'img/izveduvaci/318.jpg';
        const IZGLEDALA_JE_MALO_CUDNO_U_KAPUTU = 'img/izveduvaci/319.jpg';
        const LOSE_VINO1 = 'img/izveduvaci/320.jpg';
        const SANJAO_SAM_NOCAS_DA_TE_NEMAM = 'img/izveduvaci/321.jpg';
        const NA_ZADNJEM_SEDISTU_MOGA_AUTA = 'img/izveduvaci/322.jpg';
        const SVI_MARS_NA_PLES = 'img/izveduvaci/323.jpg';
        const TAKO_TI_JE_MALA_MOJA = 'img/izveduvaci/324.jpg';
        const DOBRO_VAM_JUTRO = 'img/izveduvaci/325.jpg';
        const ZLATNI_DAN = 'img/izveduvaci/326.jpg';
        const MILO_MOJE = 'img/izveduvaci/327.jpg';
        const UZALUD_ME_PODSECAS = 'img/izveduvaci/328.jpg';
        const STO_JE_SA_PRINCEZOM_MOJE_VRELE_MLADOSTI = 'img/izveduvaci/329.jpg';
        const KO_SAM_BEZ_TEBE = 'img/izveduvaci/330.jpg';
        const EMILY = 'img/izveduvaci/331.jpg';
        const KUDA_IDU_IZGUBLJENE_DEVOJKE = 'img/izveduvaci/332.jpg';
        const PRODALA_ME_TI = 'img/izveduvaci/333.jpg';
        const DOK_SVIRA_RADIO = 'img/izveduvaci/334.jpg';
        const DALEKO_FT_KEMALMONTENO = 'img/izveduvaci/335.jpg';
        const MI_SMO_JACI_I_OD_SUDBINE = 'img/izveduvaci/336.jpg';
        const U_DOBRU_I_ZLU = 'img/izveduvaci/337.jpg';
        const ELOIS = 'img/izveduvaci/338.jpg';
        const TUGA_TI_I_JA = 'img/izveduvaci/339.jpg';
        const TO_MI_RADI = 'img/izveduvaci/340.jpg';
        const NEKAKO_S_PROLJECA_FT_KEMAL_MONTENO = 'img/izveduvaci/341.jpg';
        const MOJE_NAJMILIJE = 'img/izveduvaci/342.jpg';
        const TUGO_NESRECO = 'img/izveduvaci/343.jpg';
        const ZOVU_NAS_ULICE = 'img/izveduvaci/345.jpg';
        const BJEZI_KISO_S_PROZORA = 'img/izveduvaci/346.jpg';
        const TAMO_GDE_LJUBAV_POCINJE = 'img/izveduvaci/347.jpg';
        const TVOGA_SRCA_VRATA = 'img/izveduvaci/348.jpg';
        const DIRLIJA = 'img/izveduvaci/349.jpg';
        const IMAM_NEKE_FORE = 'img/izveduvaci/350.jpg';
        const VOLIO_BI_DA_SI_TU = 'img/izveduvaci/351.jpg';
        const SAMPANJSKI_POLJUBAC = 'img/izveduvaci/352.jpg';
        const DA_MI_JE_DO_NJE = 'img/izveduvaci/353.jpg';
        const STIZU_ME_SECANJA = 'img/izveduvaci/354.jpg';
        const IMA_NESTO_OD_SRCA_DO_SRCA = 'img/izveduvaci/355.jpg';
        const AKO_AKO = 'img/izveduvaci/356.jpg';
        const SVIDJA_MI_SE_OVA_STVAR = 'img/izveduvaci/357.jpg';
        const PRINCIPESSA = 'img/izveduvaci/358.jpg';
        const NEMA_VISE_VREMENA = 'img/izveduvaci/359.jpg';
        const S_TVOJIH_USANA = 'img/izveduvaci/360.jpg';
        const FLOYD = 'img/izveduvaci/361.jpg';
        const JA_HOCU_ZIVOT = 'img/izveduvaci/362.jpg';
        const NOC_JE_PREKRASNA = 'img/izveduvaci/363.jpg';
        const DZULI = 'img/izveduvaci/364.jpg';
        const NEKA_MI_NE_SVANE = 'img/izveduvaci/365.jpg';
        const DA_JE_SALDJE_ZASPATI = 'img/izveduvaci/366.jpg';
        const ULICA_JORGOVANA = 'img/izveduvaci/367.jpg';
        const JA_BIH_DA_PEVAM = 'img/izveduvaci/368.jpg';
        const JULIJA = 'img/izveduvaci/369.jpg';
        const LETNJE_KISE = 'img/izveduvaci/370.jpg';
        const OAZA_SNOVA = 'img/izveduvaci/371.jpg';
        const SOBA_23 = 'img/izveduvaci/372.jpg';
        const PROGRAM_TVOG_KOMPJUTERA = 'img/izveduvaci/373.jpg';
        const VOLI_ME_JOS_OVU_NOC = 'img/izveduvaci/374.jpg';
        const JA_SAM_LAZLJIVA = 'img/izveduvaci/375.jpg';
        const U_RITMU_ME_OKRENI = 'img/izveduvaci/376.jpg';
        const TI_SI_MI_U_MISLIMA = 'img/izveduvaci/377.jpg';
        const TEBI_PRIPADAM = 'img/izveduvaci/378.jpg';
        const LJUBAV_SE_ZOVE_IMENOM_TVOIM = 'img/izveduvaci/379.jpg';
        const NECU_DA_ZNAM_ZA_NIKOG_OSIM_TEBE = 'img/izveduvaci/380.jpg';
        const JACE_MANIJACE = 'img/izveduvaci/381.jpg';
        const UMRI_PRIJE_SMRTI = 'img/izveduvaci/382.jpg';
        const SREDINOM = 'img/izveduvaci/383.jpg';
        const MOJ_JE_ZIVOT_SVICARSKA = 'img/izveduvaci/384.jpg';
        const SVE_JE_LAZ = 'img/izveduvaci/385.jpg';
        const GODINAMA = 'img/izveduvaci/386.jpg';
        const KAD_SI_REKLA_DA_ME_VOLIS = 'img/izveduvaci/387.jpg';
        const HITNA = 'img/izveduvaci/388.jpg';
        const DA_JE_TUGA_SNIJEG = 'img/izveduvaci/389.jpg';
        const KREMEN = 'img/izveduvaci/390.jpg';
        const KAD_COVIJEK_VOLI_ZENU = 'img/izveduvaci/391.jpg';
        const STA_TI_ZNACIM_JA = 'img/izveduvaci/392.jpg';
        const DANAS_SAM_OK = 'img/izveduvaci/393.jpg';
        const BOSNOM_BEHAR_PROBEHARAO = 'img/izveduvaci/394.jpg';
        const OBICNA_LJUBAVNAPJESMA = 'img/izveduvaci/395.jpg';
        const ASTA_DA_RADIM = 'img/izveduvaci/396.jpg';
        const DIGNI_MEVISOKO = 'img/izveduvaci/397.jpg';
        const FRAT_ELLO = 'img/izveduvaci/398.jpg';
        const STAVI_PRAVUSTVAR = 'img/izveduvaci/399.jpg';
        const STA_SI_MI_UKAVU_STAVILA = 'img/izveduvaci/400.jpg';
        const NESTO_LIJEPO_TREBA_DA_SE_DESI = 'img/izveduvaci/401.jpg';
        const MJESECINA = 'img/izveduvaci/402.jpg';
        const JEL_SARAJEVO_GDE_JE_NEKAD_BILO = 'img/izveduvaci/403.jpg';
        const KADZAMIRISUJORGOVANIFTVESNA_ZMIJANAC = 'img/izveduvaci/404.jpg';
        const ZAR_JE_TO_SVE_STO_IMAM_OD_TEBE = 'img/izveduvaci/405.jpg';
        const JA_POTPUNO_TRIJEZAN_UMIREM = 'img/izveduvaci/406.jpg';
        const NE_ZOVI_ME_NA_GRIJEH = 'img/izveduvaci/407.jpg';
        const NEMAM_JA_18_GODINA = 'img/izveduvaci/408.jpg';
        const KOKUZNA_VREMENA = 'img/izveduvaci/409.jpg';
        const JA_SAM_NA_TE_NAVIKO = 'img/izveduvaci/410.jpg';
        const UCINI_MI_PRAVU_STVAR = 'img/izveduvaci/411.jpg';
        const SA_MOJIH_USANA = 'img/izveduvaci/412.jpg';
        const DA_SUTIS = 'img/izveduvaci/413.jpg';
        const OTKRIT_CU_TI_TAJNU = 'img/izveduvaci/414.jpg';
        const DESET_MLADJA = 'img/izveduvaci/415.jpg';
        const OSTAT_CE_ISTINE_DVIJE = 'img/izveduvaci/416.jpg';
        const AKO_ME_IKADA_SRETNES = 'img/izveduvaci/417.jpg';
        const ZABORAVI = 'img/izveduvaci/418.jpg';
        const MOJA_BOGDA_SNA = 'img/izveduvaci/419.jpg';
        const BASKA_TI = 'img/izveduvaci/420.jpg';
        const SMIJEHOM_STRAH_POKRIJEM = 'img/izveduvaci/421.jpg';
        const NEK_PADAJU_CUSKIJE = 'img/izveduvaci/422.jpg';
        const ISPOCETKA = 'img/izveduvaci/423.jpg';
        const SVE_DOK_TE_BUDE_IMALO = 'img/izveduvaci/424.jpg';
        const LAZU_ME = 'img/izveduvaci/425.jpg';
        const LELO = 'img/izveduvaci/426.jpg';
        const TREBAM_TE_MARIJA = 'img/izveduvaci/427.jpg';
        const KAKO_SI_TOPLA_I_MILA = 'img/izveduvaci/428.jpg';
        const KRIVO_JE_MORE = 'img/izveduvaci/429.jpg';
        const JEDINA_MOJA = 'img/izveduvaci/430.jpg';
        const ZAUVJEK_TVOJ = 'img/izveduvaci/431.jpg';
        const VOLI_TE_TVOJA_ZVER = 'img/izveduvaci/432.jpg';
        const OSTANI_UZ_MENE = 'img/izveduvaci/433.jpg';
        const BAMBINA = 'img/izveduvaci/434.jpg';
        const DANI_LJUBAVI = 'img/izveduvaci/435.jpg';
        const IVONA = 'img/izveduvaci/436.jpg';
        const JAGODE_I_COKOLADA = 'img/izveduvaci/437.jpg';
        const PRICAJ_MI_O_LJUBAVI = 'img/izveduvaci/438.jpg';
        const ANDJELA_MOJA_JE_DRAGA_VESTICA = 'img/izveduvaci/439.jpg';
        const BOZA_ZVANI_PUB = 'img/izveduvaci/440.jpg';
        const DEVOJKA_SA_CARDAS_NOGAMA = 'img/izveduvaci/441.jpg';
        const DIVLJI_BADEM = 'img/izveduvaci/442.jpg';
        const D_MOLL = 'img/izveduvaci/443.jpg';
        const JA_LUZER = 'img/izveduvaci/444.jpg';
        const JAROSLAVA_PRINCEZO_JAVI_SE = 'img/izveduvaci/445.jpg';
        const LEPA_PROTINA_KCI = 'img/izveduvaci/446.jpg';
        const LJERKA = 'img/izveduvaci/447.jpg';
        const NE_LOMITE_MI_BAGRENJE = 'img/izveduvaci/448.jpg';
        const NE_VOLIM_JANUAR = 'img/izveduvaci/449.jpg';
        const NEKI_NOVI_KLINCI = 'img/izveduvaci/450.jpg';
        const NEVERNIK = 'img/izveduvaci/451.jpg';
        const NIKAD_KAO_BANE = 'img/izveduvaci/452.jpg';
        const OLELOLE = 'img/izveduvaci/453.jpg';
        const OPROSTI_MI_KATRIN = 'img/izveduvaci/454.jpg';
        const PA_DOBRO_GDE_SI_TI = 'img/izveduvaci/455.jpg';
        const PORTRET_MOG_ZIVOTA = 'img/izveduvaci/456.jpg';
        const PROVINCIJALKA = 'img/izveduvaci/457.jpg';
        const PRVA_LJUBAV = 'img/izveduvaci/458.jpg';
        const RINGISPIL = 'img/izveduvaci/459.jpg';
        const SIN_JEDINAC = 'img/izveduvaci/460.jpg';
        const SLABO_DIVANIM_MADZARSKI = 'img/izveduvaci/461.jpg';
        const SLOVENSKA = 'img/izveduvaci/462.jpg';
        const SVIRAJTE_MI_JESEN_STIZE_DUNJO_MOJA = 'img/izveduvaci/463.jpg';
        const USPAVANKA_ZA_DECAKA = 'img/izveduvaci/464.jpg';
        const OLIVERA = 'img/izveduvaci/465.jpg';
        const SJAJ_U_TAMI = 'img/izveduvaci/466.jpg';
        const SAKOM_O_STOL = 'img/izveduvaci/467.jpg';
        const JA_NOCAS_UMIREM = 'img/izveduvaci/468.jpg';
        const KRIVI_LJUDI = 'img/izveduvaci/469.jpg';
        const MALO_MI_ZA_SRICU_TRIBA = 'img/izveduvaci/470.jpg';
        const MARIJA_MAGDALENA = 'img/izveduvaci/471.jpg';
        const MORAM = 'img/izveduvaci/472.jpg';
        const PETAK = 'img/izveduvaci/473.jpg';
        const TO = 'img/izveduvaci/474.jpg';
        const ZELJO_MOJA = 'img/izveduvaci/475.jpg';
        const NI_DA_MORA_NESTANE = 'img/izveduvaci/476.jpg';
        const STAJE_OD_MENE_OSTALO = 'img/izveduvaci/477.jpg';
        const IMA_LI_NADE_ZA_NAS_FT_ANDJELA_ZECIC = 'img/izveduvaci/478.jpg';
        const PISI_MI = 'img/izveduvaci/479.jpg';
        const PRODJE_OVAJ_DAN = 'img/izveduvaci/480.jpg';
        const PAR_GODINA_ZA_NAS = 'img/izveduvaci/481.jpg';
        const SRCE = 'img/izveduvaci/482.jpg';
        const OCI_BOJE_MEDA = 'img/izveduvaci/483.jpg';
        const TI_SI_SAV_MOJ_BOL = 'img/izveduvaci/484.jpg';
        const KRUG = 'img/izveduvaci/485.jpg';
        const DA_SI_TAKO_JAKA = 'img/izveduvaci/486.jpg';
        const BEJBE_TI_NISI_TU = 'img/izveduvaci/487.jpg';
        const IGRA_ROCK_NN_ROLL_CELA_JUGOSLAVIJA = 'img/izveduvaci/488.jpg';
        const MALA_MALA_MALA_GRUPA_PEDERA = 'img/izveduvaci/489.jpg';
        const PARANOJA = 'img/izveduvaci/490.jpg';
        const STO_JA_VOLIM_TAJ_SEX = 'img/izveduvaci/491.jpg';
        const A_SADA_IDEM_FT_TIFA = 'img/izveduvaci/492.jpg';
        const BOJE_SU_U_NAMA = 'img/izveduvaci/493.jpg';
        const DOCI_CU_TI_U_SNOVIMA = 'img/izveduvaci/494.jpg';
        const LIJEPO_LIJEPO_NEOPISIVO = 'img/izveduvaci/495.jpg';
        const NJEZNO_NJEZNO_NJEZNIJE = 'img/izveduvaci/496.jpg';
        const PJEVAJMO_DO_ZORE = 'img/izveduvaci/497.jpg';
        const ZAMISLI_ZIVOT_U_RITMU_MUZIKE_ZA_PLES = 'img/izveduvaci/498.jpg';
        const DOBRE_VIBRACIJE = 'img/izveduvaci/499.jpg';
        const SRCE_NA_CESTI = 'img/izveduvaci/500.jpg';
        const MI_NISMO_SAMI = 'img/izveduvaci/501.jpg';
        const SJECAM_SE_PRVOG_POLJUPCA = 'img/izveduvaci/502.jpg';
        const LJUBAV_JE_ZAKON = 'img/izveduvaci/503.jpg';
        const MACKA = 'img/izveduvaci/504.jpg';
        const ZABORAVIT_CU_SVE = 'img/izveduvaci/505.jpg';
        const ZVONI_TELEFON = 'img/izveduvaci/506.jpg';
        const VOLIM_TE_BUDALO_MALA = 'img/izveduvaci/507.jpg';
        const ZAGRLJENI = 'img/izveduvaci/508.jpg';
        const PAMTIM_SAMO_SRETNE_DANE = 'img/izveduvaci/509.jpg';
        const ON_ME_VOLI_NA_SVOJ_NACIN = 'img/izveduvaci/510.jpg';
        const VINO_I_GITARE = 'img/izveduvaci/511.jpg';
        const CINIM_PRAVU_STVAR = 'img/izveduvaci/512.jpg';
        const DVIJE_DUSE = 'img/izveduvaci/513.jpg';
        const ISPOD_MOGA_PRAMCA = 'img/izveduvaci/514.jpg';
        const OVO_MI_JE_SKOLA = 'img/izveduvaci/515.jpg';
        const SUVISE_SAM_NJEN = 'img/izveduvaci/516.jpg';
        const BAS_TI_LIJEPO_STOJE_SUZE = 'img/izveduvaci/517.jpg';
        const HEJ_KAKO_SI = 'img/izveduvaci/518.jpg';
        const JAVI_SE = 'img/izveduvaci/519.jpg';
        const KAD_DODJE_OKTOBAR = 'img/izveduvaci/520.jpg';
        const KAO_DOMINE = 'img/izveduvaci/521.jpg';
        const CUVAM_NOC_OD_BUDNIH = 'img/izveduvaci/522.jpg';
        const FEMME_FATALE = 'img/izveduvaci/523.jpg';
        const KAO_KAKAO = 'img/izveduvaci/524.jpg';
        const MAMURNI_LJUDI = 'img/izveduvaci/525.jpg';
        const SKOPJE = 'img/izveduvaci/526.jpg';
        const UCI_ME_MAJKO_KARAJ_ME = 'img/izveduvaci/527.jpg';
        const CUKNI_VO_DRVO = 'img/izveduvaci/528.jpg';
        const IMA_VREMENA = 'img/izveduvaci/529.jpg';
        const SANJAO_SAM_MOJ_RUZICU = 'img/izveduvaci/530.jpg';
        const GUTLJAJ_VINA = 'img/izveduvaci/531.jpg';
        const JEL_ZBOG_NJE = 'img/izveduvaci/532.jpg';
        const KOKOLO = 'img/izveduvaci/533.jpg';
        const LJUBE_SE_DOBRI_LOSI_ZLI = 'img/izveduvaci/534.jpg';
        const MINUT_SRCA_TVOG = 'img/izveduvaci/535.jpg';
        const OKO_MOJE_SANJIVO = 'img/izveduvaci/536.jpg';
        const OPIJUM = 'img/izveduvaci/537.jpg';
        const PUT_PUTUJEM = 'img/izveduvaci/538.jpg';
        const RANO_RANIJE = 'img/izveduvaci/539.jpg';
        const SUZE_BISERNE = 'img/izveduvaci/540.jpg';
        const SVE_BI_SEKE_LJUBILE_MORNARE = 'img/izveduvaci/541.jpg';
        const TAMARA1 = 'img/izveduvaci/542.jpg';
        const AKO_ME_OSTAVIS = 'img/izveduvaci/543.jpg';
        const JA_NEMAM_VISE_RAZLOGA_DA_ZIVIM = 'img/izveduvaci/544.jpg';
        const JEDAN_DAN_ZIVOTA = 'img/izveduvaci/545.jpg';
        const JOS_I_DANAS_TEKU_SUZE_JEDNE_ZENE = 'img/izveduvaci/546.jpg';
        const MALO_MI_JE_JEDAN_ZIVOT_S_TOBOM = 'img/izveduvaci/547.jpg';
        const NIKOGA_NISAM_VOLIO_TAKO = 'img/izveduvaci/548.jpg';
        const OSTALA_SI_UVIJEK_ISTA = 'img/izveduvaci/549.jpg';
        const SVI_PEVAJU_JA_NE_CUJEM = 'img/izveduvaci/550.jpg';
        const TI_SI_PJESMA_MOJE_DUSE = 'img/izveduvaci/551.jpg';
        const DALI_SI_SPAVALA = 'img/izveduvaci/552.jpg';
        const DA_ME_NISI = 'img/izveduvaci/553.jpg';
        const DIGNI_RUKU = 'img/izveduvaci/554.jpg';
        const DODIRNI_ME = 'img/izveduvaci/555.jpg';
        const KAD_ME_POGLEDAS = 'img/izveduvaci/556.jpg';
        const KOTOR = 'img/izveduvaci/557.jpg';
        const SKADARSKA = 'img/izveduvaci/558.jpg';
        const TRUBE = 'img/izveduvaci/559.jpg';
        const TI_SAMO_BUDI_DOVOLJNO_DALEKO = 'img/izveduvaci/560.jpg';
        const OSMIJEH = 'img/izveduvaci/561.jpg';
        const KENOZOIK = 'img/izveduvaci/562.jpg';
        const MALJCHIKI = 'img/izveduvaci/563.jpg';
        const LEJLA = 'img/izveduvaci/564.jpg';
        const LUD_SAM_ZA_TOBOM = 'img/izveduvaci/565.jpg';
        const NEK_NEBO_NAM_SUDI = 'img/izveduvaci/566.jpg';
        const OSTAVI_SUZE_ZA_KRAJ = 'img/izveduvaci/567.jpg';
        const OTKAD_TEBE_NEMA = 'img/izveduvaci/568.jpg';
        const RODJENA_SI_SAMO_ZA_MENE = 'img/izveduvaci/569.jpg';

        const STRAH_ME_DA_TE_VOLIM = 'img/izveduvaci/571.jpg';
        const SVE_LJUBAVI_SU_TUZNE = 'img/izveduvaci/572.jpg';
        const SVI_MOJI_DRUMOVI = 'img/izveduvaci/573.jpg';
        const TI_ZNAS_SVE = 'img/izveduvaci/574.jpg';
        const VOLIO_BI_DA_TE_NE_VOLIM = 'img/izveduvaci/575.jpg';
        const STRANAC_U_NOCI = 'img/izveduvaci/576.jpg';
        const POTRAZI_ME_U_PREDGRADU = 'img/izveduvaci/577.jpg';
        const SAMO_SIMPATIJA = 'img/izveduvaci/578.jpg';
        const ZORA_JE = 'img/izveduvaci/579.jpg';
        const STO_CE_TAJ_COVJEK_TU = 'img/izveduvaci/580.jpg';
        const TESKA_VREMENA_PRIJATELJU_MOJ = 'img/izveduvaci/581.jpg';
        const DOTAKNI_ME_USNAMA = 'img/izveduvaci/582.jpg';
        const RIJEKA_SNOVA = 'img/izveduvaci/583.jpg';
        const SUNCAN_DAN = 'img/izveduvaci/584.jpg';
        const KAVANNA_FT_FIUMENS = 'img/izveduvaci/585.jpg';
        const NAJDRAZE_MOJE = 'img/izveduvaci/586.jpg';
        const PLAVA_KOSULJA = 'img/izveduvaci/587.jpg';
        const SUTI_MOJ_DJECACE_PLAVI = 'img/izveduvaci/588.jpg';
        const ZA_DOBRA_STARA_VREMENA = 'img/izveduvaci/589.jpg';
        const ZNAM = 'img/izveduvaci/590.jpg';
        const BICU_TVOJ = 'img/izveduvaci/591.jpg';
        const BOBANE = 'img/izveduvaci/592.jpg';
        const DODJE_MI_DA_VRISNEM_TVOJE_IME = 'img/izveduvaci/593.jpg';
        const NIJE_ZA_NJU = 'img/izveduvaci/594.jpg'
        const ODLAZIM_A_VOLIM_TE = 'img/izveduvaci/595.jpg';
        const OSLONI_SE_NE_MENE = 'img/izveduvaci/596.jpg';
        const PITAJU_ME_PITAJU = 'img/izveduvaci/597.jpg';
        const POMAGAJTE_DRUGOVI = 'img/izveduvaci/598.jpg';
        const SMEJEM_SE_A_PLAKAO_BIH = 'img/izveduvaci/599.jpg';
        const ZBOG_TEBE_BIH_TUCAO_KAMEN = 'img/izveduvaci/600.jpg';
        const CRNI_PLES = 'img/izveduvaci/601.jpg';
        const DENIS = 'img/izveduvaci/602.jpg';
        const NADJI_ME = 'img/izveduvaci/603.jpg';
        const SAM = 'img/izveduvaci/604.jpg';
        const BROD_U_BOCI = 'img/izveduvaci/605.jpg';
        const CESARICA = 'img/izveduvaci/606.jpg';
        const DVAPUT_SAN_UMRA = 'img/izveduvaci/607.jpg';
        const KAD_MI_DODZES_TI = 'img/izveduvaci/608.jpg';
        const NEBO_MOJE = 'img/izveduvaci/609.jpg';
        const NEDOSTAJES_MI_TI = 'img/izveduvaci/610.jpg';
        const NOCTURNO = 'img/izveduvaci/611.jpg';
        const PISMO_MOJA = 'img/izveduvaci/612.jpg';
        const PRED_TVOJIM_VRATIMA = 'img/izveduvaci/613.jpg';
        const STINE = 'img/izveduvaci/614.jpg';
        const STO_TO_BJESE_LJUBAV = 'img/izveduvaci/615.jpg';
        const SVE_BI_DA_ZA_NJU = 'img/izveduvaci/616.jpg';
        const SVIRAJTE_NOCAS_ZA_MOJU_DUSU = 'img/izveduvaci/617.jpg';
        const TRAG_U_BESKRAJU = 'img/izveduvaci/618.jpg';
        const VJERUJ_U_LJUBAV = 'img/izveduvaci/619.jpg';
        const U_LJUBAV_VJERE_NEMAM_FT_GIBONNI = 'img/izveduvaci/620.jpg';
        const DZENI = 'img/izveduvaci/621.jpg';
        const E_DA_SI_BAREM_NOCAS_OVDJE = 'img/izveduvaci/622.jpg';
        const E_MOJ_SASA = 'img/izveduvaci/623.jpg';
        const JA_SAM_ZA_PLES = 'img/izveduvaci/624.jpg';
        const JESEN_JE = 'img/izveduvaci/625.jpg';
        const MILENA = 'img/izveduvaci/626.jpg';
        const CARTE_BLANCHE = 'img/izveduvaci/627.jpg';
        const BEZ_TEBE = 'img/izveduvaci/628.jpg';
        const DITELINA_S_CETRI_LISTA = 'img/izveduvaci/629.jpg';
        const JEDAN_OD_MNOGIH = 'img/izveduvaci/630.jpg';
        const CALIFORNIA = 'img/izveduvaci/631.jpg';
        const JEANS_GENERACIJA = 'img/izveduvaci/632.jpg';
        const KAKVA_NOC1 = 'img/izveduvaci/633.jpg';
        const DZEMPER_ZA_VINOGRAD = 'img/izveduvaci/634.jpg';
        const KAD_BI_DOSLA_MARIJA = 'img/izveduvaci/635.jpg';
        const OD_DRUGA_DO_DRUGA = 'img/izveduvaci/636.jpg';
        const VINO_NOCI_FT_DEMODE = 'img/izveduvaci/637.jpg';
        const KOLACICI = 'img/izveduvaci/638.jpg';
        const DA_MI_JE_BITI_MORSKI_PAS = 'img/izveduvaci/639.jpg';
        const AKO_JEDNOM_VIDIS_MARIJU = 'img/izveduvaci/640.jpg';
        const KAD_BIH_ZNAO_DA_JE_SAMA = 'img/izveduvaci/641.jpg';
        const AKO_OVO_JE_KRAJ_FT_DAVOR_DRAGOJEVIC = 'img/izveduvaci/642.jpg';
        const APSOLUTNO_TVOJ = 'img/izveduvaci/643.jpg';
        const JA_IMAM_TE_A_KO_DA_NEMAM_TE = 'img/izveduvaci/644.jpg';
        const PRSTEN_I_ZLATNI_LANAC = 'img/izveduvaci/645.jpg';
        const STO_JE_BILO_BILO_JE = 'img/izveduvaci/646.jpg';
        const ZUTE_DUNJE = 'img/izveduvaci/647.jpg';
        const IMA_NEKA_TAJNA_VEZA_ZA_SVE_LJUDE = 'img/izveduvaci/648.jpg';
        const STO_TE_NEMA = 'img/izveduvaci/649.jpg';
        const SVE_SMO_MOGLI_MI = 'img/izveduvaci/650.jpg';
        const JA_SAM_TI_JEDINI_DRUG = 'img/izveduvaci/651.jpg';
        const NA_OBALI = 'img/izveduvaci/652.jpg';
        const SKITNICA = 'img/izveduvaci/653.jpg';
        const DODZI_U_MALI_KAFE = 'img/izveduvaci/654.jpg';
        const GOVOR_TVOGA_TELA = 'img/izveduvaci/655.jpg';
        const LJULJAJ_ME_NEZNO = 'img/izveduvaci/656.jpg';
        const PROBAJ_ME = 'img/izveduvaci/657.jpg';
        const GDE_DA_POBEGNEM = 'img/izveduvaci/658.jpg';
        const MARIJA = 'img/izveduvaci/659.jpg';
        const MOZDA_NEBO_ZNA = 'img/izveduvaci/660.jpg';
        const S_KIM_CEKAS_DAN = 'img/izveduvaci/661.jpg';
        const VINO_CRVENO = 'img/izveduvaci/662.jpg';
        const IVANA = 'img/izveduvaci/663.jpg';
        const DODJI = 'img/izveduvaci/664.jpg';
        const DOK_SI_PORED_MENE = 'img/izveduvaci/665.jpg';
        const GODINE_PROLAZE_NEKA_IDU_BEZ_TEBE = 'img/izveduvaci/666.jpg';
        const JESEN_U_MENI = 'img/izveduvaci/667.jpg';
        const KADA_ME_DOTAKNE = 'img/izveduvaci/668.jpg';
        const KAO_TI = 'img/izveduvaci/669.jpg';
        const LJUBAVNA = 'img/izveduvaci/670.jpg';
        const LUTKA_ZA_BAL = 'img/izveduvaci/671.jpg';
        const MOJA_JE_PJESMA_LAGANA = 'img/izveduvaci/672.jpg';
        const NEDA = 'img/izveduvaci/673.jpg';
        const PROKLETA_NEDELJA = 'img/izveduvaci/674.jpg';
        const SVE_JOS_MIRISE_NA_NJU = 'img/izveduvaci/675.jpg';
        const U_LJUBAV_VJERUJEM = 'img/izveduvaci/676.jpg';
        const UGASI_ME = 'img/izveduvaci/677.jpg';
        const UHVATI_RITAM = 'img/izveduvaci/678.jpg';
        const ZASTAVE = 'img/izveduvaci/679.jpg';
        const STRANICE_DNEVNIKA = 'img/izveduvaci/680.jpg';
        const DOLAZIM_ZA_5_MINUTA = 'img/izveduvaci/681.jpg';
        const NAJ_JACI_OSTAJU = 'img/izveduvaci/682.jpg';
        const POVEDI_ME_U_NOC = 'img/izveduvaci/683.jpg';
        const SVEMU_DODJE_KRAJ = 'img/izveduvaci/684.jpg';
        const TI_I_JA = 'img/izveduvaci/685.jpg';
        const BI_MOGO_DA_MOGU = 'img/izveduvaci/686.jpg';
        const ENA = 'img/izveduvaci/687.jpg';
        const MOJA_PRVA_LJUBAV = 'img/izveduvaci/688.jpg';
        const SAL_OD_SVILE = 'img/izveduvaci/689.jpg';
        const SEJN = 'img/izveduvaci/690.jpg';
        const UZALUD_PITAS = 'img/izveduvaci/691.jpg';
        const LAGANO_UMIREM = 'img/izveduvaci/692.jpg';
        const CEKALA_SAM = 'img/izveduvaci/693.jpg';
        const NE_LOMI_ME = 'img/izveduvaci/694.jpg';
        const RUZMARIN = 'img/izveduvaci/695.jpg';

        const CINI_MI_SE_DA = 'img/izveduvaci/697.jpg';
        const KADA_SANJAMO = 'img/izveduvaci/698.jpg';
        const NEVERNA_SI = 'img/izveduvaci/699.jpg';
        const TO_JE_SUDBINA = 'img/izveduvaci/700.jpg';
        const KAO_PTICA_NA_MOM_DLANU = 'img/izveduvaci/701.jpg';
        const TAJNA_JE_U_TEBI_SKRIVENA = 'img/izveduvaci/702.jpg';
        const ZABORAVLJENI = 'img/izveduvaci/703.jpg';
        const AKO_SU_TO_SAMO_BILE_LAZI = 'img/izveduvaci/704.jpg';
        const BOLJE_BITI_PIJAN_NEGO_STAR = 'img/izveduvaci/705.jpg';
        const KAJA = 'img/izveduvaci/706.jpg';
        const LJUBI_SE_ISTOK_I_ZAPAD = 'img/izveduvaci/707.jpg';
        const LOVAC_I_KOSUTA = 'img/izveduvaci/708.jpg';
        const GRUDI_BALKANSKE = 'img/izveduvaci/709.jpg';
        const NATASA = 'img/izveduvaci/710.jpg';
        const VRATI_SE = 'img/izveduvaci/711.jpg';
        const FRIDA = 'img/izveduvaci/712.jpg';
        const JEDNA_MALA_PLAVA = 'img/izveduvaci/713.jpg';
        const PRINCEZA_FT_DADO_TOPIC = 'img/izveduvaci/714.jpg';
        const ODLAZIM = 'img/izveduvaci/715.jpg';
        const SAVA_TIHO_TECE = 'img/izveduvaci/716.jpg';
        const SUADA = 'img/izveduvaci/717.jpg';
        const ZELENE_SU_BILE_OCI_TE = 'img/izveduvaci/718.jpg';
        const DECKO_AJDE_OLADI = 'img/izveduvaci/719.jpg';
        const SRCE_OD_MEDA = 'img/izveduvaci/720.jpg';
        const TAXI = 'img/izveduvaci/721.jpg';
        const JELENI_UMIRU_SAMI = 'img/izveduvaci/722.jpg';
        const IZ_NEKIH_STARIH_RAZLOGA = 'img/izveduvaci/723.jpg';
        const NE_ZOVI_MAMA_DOKTORA = 'img/izveduvaci/724.jpg';
        const CRNO_BIJELI_SVIJET = 'img/izveduvaci/725.jpg';
        const KISE_JESENJE = 'img/izveduvaci/726.jpg';
        const KORAK_OD_SNA = 'img/izveduvaci/727.jpg';
        const MA_KOG_ME_BOGA_ZA_TEBE_PITAJU = 'img/izveduvaci/728.jpg';
        const MAR_INA = 'img/izveduvaci/729.jpg';
        const MI_PLESEMO = 'img/izveduvaci/730.jpg';
        const MOJ_BIJELI_LABUDE = 'img/izveduvaci/731.jpg';
        const S_VREMENA_NA_VRIJEME = 'img/izveduvaci/732.jpg';
        const UZALUD_VAM_TRUD_SVIRACI = 'img/izveduvaci/733.jpg';
        const ZAUSTAVITE_ZEMLJU = 'img/izveduvaci/734.jpg';
        const AKO_TRAZIS_NEKOGA = 'img/izveduvaci/735.jpg';
        const TU_NOC_KAD_SI_SE_UDAVALA = 'img/izveduvaci/736.jpg';
        const ZBOG_MENE_NE_PLACI = 'img/izveduvaci/737.jpg';
        const LOLA = 'img/izveduvaci/738.jpg';
        const TUZNA_SU_ZELENA_POLJA = 'img/izveduvaci/739.jpg';
        const JA_VOLIM_SAMO_SEBE = 'img/izveduvaci/740.jpg';
        const ANDREA = 'img/izveduvaci/741.jpg';
        const AL_KAPONE = 'img/izveduvaci/742.jpg';
        const AMSTERDAM = 'img/izveduvaci/743.jpg';
        const AVIONU_SLOMICU_TI_KRILA = 'img/izveduvaci/744.jpg';
        const DOBRO_JUTRO = 'img/izveduvaci/745.jpg';
        const DVA_DINARA_DRUZE = 'img/izveduvaci/746.jpg';
        const GDE_SI_U_OVOM_GLUPOM_HOTELU = 'img/izveduvaci/747.jpg';
        const JA_JE_GLEDAM_KAKO_SPAVA = 'img/izveduvaci/748.jpg';
        const JA_SAM_SE_LOZIO_NA_TEBE = 'img/izveduvaci/749.jpg';
        const KAD_HODAS_NE_ZASTAJKUJES = 'img/izveduvaci/750.jpg';
        const KAD_SAM_BIO_MLAD = 'img/izveduvaci/751.jpg';
        const KADA_PADNE_NOC = 'img/izveduvaci/752.jpg';
        const KAKO_JE_LEPO_BITI_GLUP = 'img/izveduvaci/753.jpg';
        const LUTKA_SA_NASLOVNE_STRANE = 'img/izveduvaci/754.jpg';
        const NA_ZAPADU_NISTA_NOVO = 'img/izveduvaci/755.jpg';
        const NEMOJ_DA_IDES_MOJOM_ULICOM = 'img/izveduvaci/756.jpg';
        const NEMOJ_SRECO_NEMOJ_DANAS = 'img/izveduvaci/757.jpg';
        const OSTACU_SLOBODAN = 'img/izveduvaci/758.jpg';
        const OSTANI_DZUBRE_DO_KRAJA = 'img/izveduvaci/759.jpg';
        const POGLEDAJ_DOM_SVOJ_ANDJELE = 'img/izveduvaci/760.jpg';
        const PRAVILA_PRAVILA = 'img/izveduvaci/761.jpg';
        const VOLIM_VOLIM_ZENE = 'img/izveduvaci/762.jpg';
        const COKOLADA = 'img/izveduvaci/763.jpg';
        const DEVOJKO_MALA = 'img/izveduvaci/764.jpg';
        const MALENA = 'img/izveduvaci/765.jpg';
        const ONA_TO_ZNA = 'img/izveduvaci/766.jpg';
        const BACILA_JE_SVE_NIZ_RIJEKU = 'img/izveduvaci/767.jpg';
        const BALADA = 'img/izveduvaci/768.jpg';
        const DA_SAM_JA_NETKO = 'img/izveduvaci/769.jpg';
        const PREDAJ_SE_SRCE = 'img/izveduvaci/770.jpg';
        const SANJAM = 'img/izveduvaci/771.jpg';
        const SVE_OVE_GODINE = 'img/izveduvaci/772.jpg';
        const TI_SI_MI_BILA_NAJ_NAJ = 'img/izveduvaci/773.jpg';
        const DANAS_SAM_LUDA = 'img/izveduvaci/774.jpg';
        const DOBRE_VIBRACIJE_JA_SAM_IZVAN_SEBE = 'img/izveduvaci/775.jpg';
        const GDJE_DUNAV_LJUBI_NEBO = 'img/izveduvaci/776.jpg';
        const MAGLA = 'img/izveduvaci/777.jpg';
        const NOCNA_PTICA = 'img/izveduvaci/778.jpg';
        const O_JEDNOJ_MLADOSTI = 'img/izveduvaci/779.jpg';
        const RUSILA_SAM_MOSTOVE_FT_DINO_DVORNIK = 'img/izveduvaci/780.jpg';
        const CAO_AMORE_FT_VLADO_KALEMBAR = 'img/izveduvaci/781.jpg';
        const POVEDI_ME = 'img/izveduvaci/782.jpg';
        const ANA = 'img/izveduvaci/783.jpg';
        const JA_NISAM_KOCKAR = 'img/izveduvaci/784.jpg';
        const ZAKUNI_SE_LJUBAVI = 'img/izveduvaci/785.jpg';
        const CRNA_DAMA = 'img/izveduvaci/786.jpg';
        const DAIRE = 'img/izveduvaci/787.jpg';
        const KOKETA = 'img/izveduvaci/788.jpg';
        const VOLIO_SAM_TANJU = 'img/izveduvaci/789.jpg';
        const S_VREMENA_NA_VREME = 'img/izveduvaci/790.jpg';
        const KOFER_LJUBAVI = 'img/izveduvaci/791.jpg';
        const RODJENI = 'img/izveduvaci/792.jpg';
        const DALEKO = 'img/izveduvaci/793.jpg';
        const DUSO_MOJA = 'img/izveduvaci/794.jpg';
        const JEDNE_NOCI_U_DECEMBRU = 'img/izveduvaci/795.jpg';
        const NAPISI_JEDNU_LJUBAVNU = 'img/izveduvaci/796.jpg';
        const NIJE_HTJELA = 'img/izveduvaci/797.jpg';
        const OVAKO_NE_MOGU_DALJE = 'img/izveduvaci/798.jpg';
        const VRATIO_SAM_SE_ZIVOTE = 'img/izveduvaci/799.jpg';
        const BOLJE_DA_SAM_DRUGE_LJUBIO = 'img/izveduvaci/800.jpg';
        const COVEK_OD_MEDA = 'img/izveduvaci/801.jpg';
        const HAJDE_DA_SE_VOLIMO = 'img/izveduvaci/802.jpg';
        const NA_RASKRSCU = 'img/izveduvaci/803.jpg';
        const RATNE_IGRE = 'img/izveduvaci/804.jpg';
        const PLAVUSA = 'img/izveduvaci/805.jpg';
        const ZBOG_JEDNE_DIVNE_CRNE_ZENE = 'img/izveduvaci/806.jpg';
        const POKRENI_ME = 'img/izveduvaci/807.jpg';
        const SIZIKA = 'img/izveduvaci/808.jpg';
        const AJDE_AJDE_JASMINA = 'img/izveduvaci/809.jpg';
        const APRIL_U_BEOGRADU = 'img/izveduvaci/810.jpg';
        const CINI_MI_SE_GRMI = 'img/izveduvaci/811.jpg';
        const DA_TI_KAZEM_STA_MI_JE = 'img/izveduvaci/812.jpg';
        const GORI_VATRA = 'img/izveduvaci/813.jpg';
        const KAD_BI_MOJA_BILA = 'img/izveduvaci/814.jpg';
        const MADJARICA = 'img/izveduvaci/815.jpg';
        const MALO_POJACAJ_RADIO = 'img/izveduvaci/816.jpg';
        const PISACU_JOJ_PISMA_DUGA = 'img/izveduvaci/817.jpg';
        const RIJEKA_SUZA_I_NA_NJOJ_LADJA = 'img/izveduvaci/818.jpg';
        const RUSKA = 'img/izveduvaci/819.jpg';
        const SINOC_NISI_BILA_TU = 'img/izveduvaci/820.jpg';
        const STA_MI_RADIS = 'img/izveduvaci/821.jpg';
        const ZIVIS_U_OBLACIMA = 'img/izveduvaci/822.jpg';
        const DA_LI_ZNAS_DA_TE_VOLIM = 'img/izveduvaci/823.jpg';
        const MAKEDONIJA = 'img/izveduvaci/824.jpg';
        const ZDENKA_KOVACICEK = 'img/izveduvaci/825.jpg';
        const SEDAMNEST_TI_JE_GODINA_FT_HARI_MATA_HARI = 'img/izveduvaci/826.jpg';
        const DVIJE_ZVJEZDICE = 'img/izveduvaci/827.jpg';
        const MILION_GODINA = 'img/izveduvaci/828.jpg';
        const MOJ_MALI_JE_OPASAN = 'img/izveduvaci/829.jpg';
        const NEMA_VISE_LJUBAVI = 'img/izveduvaci/830.jpg';
        const MOJA_POSLEDNJA_I_PRVA_LJUBAVI = 'img/izveduvaci/831.jpg';
        const PRIJATELJI_STARI_GDJE_STE = 'img/izveduvaci/832.jpg';
        const DESET_GODINA = 'img/izveduvaci/833.jpg';
        const SRCE_SRNE_KOJA_DRHTI = 'img/izveduvaci/834.jpg';
        const KRILA_LEPTIRA = 'img/izveduvaci/835.jpg';
        const BILO_MI_JE_LIJEPO_S_TOBOM = 'img/izveduvaci/836.jpg';
        const NE_MOZE_TO_TAKO = 'img/izveduvaci/837.jpg';
        const NE_DAJ_MI_DA_GOVORIM_U_SNU = 'img/izveduvaci/838.jpg';
        const OKA_TVOJA_DVA = 'img/izveduvaci/839.jpg';
        const DETEKTIVSKA_PRICA = 'img/izveduvaci/840.jpg';
        const IZNENADI_ME = 'img/izveduvaci/841.jpg';
        const OD_ZLATA_JABUKA = 'img/izveduvaci/842.jpg';
        const TOTALNO_DRUKCIJI_OD_DRUGIH = 'img/izveduvaci/843.jpg';
        const VLAK = 'img/izveduvaci/844.jpg';
        const DUNAVOM_JOS_SIBAJU_VETROVI = 'img/izveduvaci/845.jpg';
        const KOME_SE_RADUJES = 'img/izveduvaci/846.jpg';
        const MORNAR = 'img/izveduvaci/847.jpg';
        const ODLAZIM_DOK_JOS_DRUGI_SPAVAJU = 'img/izveduvaci/848.jpg';
        const CRNI_LEPTIR = 'img/izveduvaci/849.jpg';
        const ZA_MILION_GODINA = 'img/izveduvaci/850.jpg';
        const BALADA_O_PISONJI_I_ZUGI = 'img/izveduvaci/851.jpg';
        const DJEVOJCICE_KOJIMA_MIRISE_KOZA = 'img/izveduvaci/852.jpg';
        const HADZIJA_ILI_BOS = 'img/izveduvaci/853.jpg';
        const JUGO_45 = 'img/izveduvaci/854.jpg';
        const MOZES_IMAT_MOJE_TIJELO = 'img/izveduvaci/855.jpg';
        const ZENICA_BLUES = 'img/izveduvaci/857.jpg';
        const DODIRNI_MI_KOLENA = 'img/izveduvaci/858.jpg';
        const JABUKE_I_VINO = 'img/izveduvaci/859.jpg';
        const MAJSTOR_ZA_POLJUPCE = 'img/izveduvaci/860.jpg';
        const MLADICU_MOJ = 'img/izveduvaci/861.jpg';
        const HAJDE_DA_LUDUJEMO = 'img/izveduvaci/862.jpg';
        const TI_NEMAS_PRAVA_NA_MENE = 'img/izveduvaci/863.jpg';
        const NE_BOJIM_SE_DRUGOVA_TVOGA_FRAJERA = 'img/izveduvaci/864.jpg';
        const STVARI_LAGANE = 'img/izveduvaci/865.jpg';
        const TI_ME_IZLUDUJES = 'img/izveduvaci/866.jpg';
        const A_TI_SI_MANGUP = 'img/izveduvaci/867.jpg';
        const IMA_JEDAN_SVIJET = 'img/izveduvaci/868.jpg';
        const SVE_JE_NEOBICNO_AKO_TE_VOLIM = 'img/izveduvaci/869.jpg';
        const STIPU_GATIBO = 'img/izveduvaci/870.jpg';
        const STO_NE_ZNAM_GDE_SI_SAD = 'img/izveduvaci/871.jpg';
        const VOJAN_POSTA = 'img/izveduvaci/872.jpg';
        const ZNAM_I_OSECAM = 'img/izveduvaci/873.jpg';
        const OZENICES_SE_TI = 'img/izveduvaci/874.jpg';
        const RUKUJU_SE_RUKUJU = 'img/izveduvaci/875.jpg';
        const ZANA_VEJTE_SNEGOVI = 'img/izveduvaci/876.jpg';
        const RAT_I_MIR = 'img/izveduvaci/877.jpg';
        const ARIJA = 'img/izveduvaci/878.jpg';
        const BARAKUDA = 'img/izveduvaci/879.jpg';
        const DAJ_NE_PITAJ = 'img/izveduvaci/880.jpg';
        const SAMO_TERAJ_TI_PO_SVOME = 'img/izveduvaci/881.jpg';
        const VINO_NA_USNAMA = 'img/izveduvaci/882.jpg';
        const TROJE = 'img/izveduvaci/883.jpg';
        const NIKAD_TE_NIKO_NECE_VOLJET_KO_JA = 'img/izveduvaci/884.jpg';
        const NEKO_TE_IMA = 'img/izveduvaci/885.jpg';
        const ZLATNA_RIBICA = 'img/izveduvaci/886.jpg';
        const PONEKAD_NOCU_DOK_SPAVA_GRAD = 'img/izveduvaci/887.jpg';
        const IDU_PTICE_SELICE = 'img/izveduvaci/888.jpg';
        const NE_MOGU_NE_MOGU = 'img/izveduvaci/889.jpg';
        const PILE_MOJE = 'img/izveduvaci/890.jpg';
        const SAMO_SKLOPI_OKICE = 'img/izveduvaci/891.jpg';
        const VOLIM_TE_JOS = 'img/izveduvaci/892.jpg';
        const IZGLEDA_DA_MI_SMO_SAMI = 'img/izveduvaci/893.jpg';
        const KOLIKO_IMAS_GODINA = 'img/izveduvaci/894.jpg';
        const NOVE_GODINE = 'img/izveduvaci/895.jpg';
        const O_JE = 'img/izveduvaci/896.jpg';
        const SIDJI_DO_REKE = 'img/izveduvaci/897.jpg';
        const JUZNJACI = 'img/izveduvaci/898.jpg';
        const OKANO = 'img/izveduvaci/899.jpg';
        const PRAVA_STVAR = 'img/izveduvaci/900.jpg';
        const PUSI_PUSTI_MODU = 'img/izveduvaci/901.jpg';
        const TI_MOZES_SVE = 'img/izveduvaci/902.jpg';
        const TI_SI_MI_U_KRVI = 'img/izveduvaci/903.jpg';
        const AJDE_AJDE_IDI = 'img/izveduvaci/904.jpg';
        const HOTEL_BALKAN = 'img/izveduvaci/905.jpg';
        const KRASIVA = 'img/izveduvaci/906.jpg';
        const NOC_MI_TE_DUGUJE = 'img/izveduvaci/907.jpg';
        const OJ_DEVOJKO_SELEN_VELEN = 'img/izveduvaci/908.jpg';
        const JEDINA = 'img/izveduvaci/909.jpg';
        const LOSE_VINO = 'img/izveduvaci/910.jpg';
        const PJEVAM_DANJU_PJEVAM_NOCU = 'img/izveduvaci/911.jpg';
        const ZVAO_SAM_JE_EMILI = 'img/izveduvaci/912.jpg';
        const CAJE_SUKARIJE = 'img/izveduvaci/913.jpg';
        const CIJA_JE_ONO_ZVIJEZDA = 'img/izveduvaci/914.jpg';
        const E_DRAGA_DRAGA = 'img/izveduvaci/915.jpg';
        const GLAVO_LUDA = 'img/izveduvaci/916.jpg';
        const JEDNA_ZIMA_SA_KRISTINOM = 'img/izveduvaci/917.jpg';
        const MASLINASTO_ZELENA = 'img/izveduvaci/918.jpg';
        const MASTILO_I_VODA = 'img/izveduvaci/919.jpg';
        const NEGDJE_NA_DNU_SRCA = 'img/izveduvaci/920.jpg';
        const PRODUZI_DALJE = 'img/izveduvaci/921.jpg';
        const STANICA_PODLUGOVI = 'img/izveduvaci/922.jpg';
        const ZAGRLI_ME = 'img/izveduvaci/923.jpg';
        const ZBOG_TEBE = 'img/izveduvaci/924.jpg';
        const DA_JE_SRECE_BILO = 'img/izveduvaci/925.jpg';
        const KUCKA_NEVERNA = 'img/izveduvaci/926.jpg';
        const MENE_TJERA_NEKI_VRAG = 'img/izveduvaci/927.jpg';
        const OPROSTI_MI_STO_TE_VOLIM = 'img/izveduvaci/928.jpg';
        const TIJANA = 'img/izveduvaci/929.jpg';
        const SINOC_SAM_POLA_KAFANE_POPIO = 'img/izveduvaci/930.jpg';
        const OVE_NOCI_JEDNA_ZENA = 'img/izveduvaci/931.jpg';
        const GRADSKE_CURE = 'img/izveduvaci/932.jpg';
        const KAKVA_NOC = 'img/izveduvaci/933.jpg';
        const DOBRE_DEVOJKE = 'img/izveduvaci/934.jpg';
        const JOS_TE_VOLIM = 'img/izveduvaci/935.jpg';
        const BALKANSKA_ULICA = 'img/izveduvaci/936.jpg';
        const KAKO_SAM_TE_VOLJELA = 'img/izveduvaci/937.jpg';
        const STO_SAM_JA_STO_SI_TI = 'img/izveduvaci/938.jpg';
        const RANO = 'img/izveduvaci/939.jpg';
        const ROCK_ME = 'img/izveduvaci/940.jpg';
        const KUCA_PORED_MORA = 'img/izveduvaci/941.jpg';
        const PJEVALI_SMO_PJESME_STARE = 'img/izveduvaci/942.jpg';
        const POZOVI_ME = 'img/izveduvaci/943.jpg';
        const IBRO_DIRKA = 'img/izveduvaci/944.jpg';
        const MENI_MAMA_NE_DA = 'img/izveduvaci/945.jpg';
        const RADOSTAN_DAN = 'img/izveduvaci/946.jpg';
        const MOZDA_MOZDA = 'img/izveduvaci/947.jpg';
        const LJUBAV_NIJE_ZA_NAS = 'img/izveduvaci/948.jpg';
        const JEDAN_COVEK_JEDNA_ZENA = 'img/izveduvaci/949.jpg';
        const GALEBOVI = 'img/izveduvaci/950.jpg';
        const JELENA = 'img/izveduvaci/951.jpg';
        const GLASNO_GLASNIJE = 'img/izveduvaci/952.jpg';
        const OD_SPLITA_DO_BEOGRADA_FT_DINO_DVORNIK = 'img/izveduvaci/953.jpg';
        const PISMO = 'img/izveduvaci/954.jpg';
        const DALMATINKA = 'img/izveduvaci/955.jpg';
        const KAZU_MI_DA_SI_JOS_UVEK_SAMA = 'img/izveduvaci/956.jpg';
        const PARISKI_LOKAL = 'img/izveduvaci/957.jpg';
        const AJSA = 'img/izveduvaci/958.jpg';
        const ELIZABET = 'img/izveduvaci/959.jpg';
        const CUVAJ_SE = 'img/izveduvaci/960.jpg';
        const JUBI_SAN_VASU_KCER = 'img/izveduvaci/961.jpg';
        const PROLJECE_BEZ_TEBE1 = 'img/izveduvaci/962.jpg';
        const JEDNU_MLADOST_IMAM = 'img/izveduvaci/963.jpg';
        const HARMONIKA = 'img/izveduvaci/964.jpg';
        const JUGOSLOVENKA = 'img/izveduvaci/965.jpg';
        const RUSKA_COKOLADA = 'img/izveduvaci/966.jpg';
        const JEDINO_MOJE = 'img/izveduvaci/967.jpg';
        const DOK_GITARA_SVIRA = 'img/izveduvaci/968.jpg';


        // изведувачи
        const AERODROM = 'img/izveduvaci/218.jpg';
        const ALEKSANDAR_MEZEK = 'img/izveduvaci/219.jpg';
        const SLADJANA_MILOSEVIC = 'img/izveduvaci/220.jpg';
        const ALEN_SLAVICA = 'img/izveduvaci/222.jpg';
        const ALISA = 'img/izveduvaci/223.jpg';
        const ALKA_VUJICA = 'img/izveduvaci/226.jpg';
        const AMBASADORI = 'img/izveduvaci/228.jpg';
        const ANIMATORI = 'img/izveduvaci/230.jpg';
        const ARSEN_DEDIC = 'img/izveduvaci/231.jpg';
        const ATOMSKO_SKLONISTE = 'img/izveduvaci/236.jpg';
        const AZRA = 'img/izveduvaci/239.jpg';
        const BABE = 'img/izveduvaci/246.jpg';
        const BAJAGA = 'img/izveduvaci/248.jpg';
        const BEBI_DOL = 'img/izveduvaci/280.jpg';
        const BJELO_DUGME = 'img/izveduvaci/286.jpg';
        const BISERA_VELETANLIC = 'img/izveduvaci/326.jpg';
        const BOBA_STEFANOVIC = 'img/izveduvaci/956.jpg';
        const BOLERO = 'img/izveduvaci/950.jpg';
        const BOBAJ_STAMPA = 'img/izveduvaci/328.jpg';
        const BORIS_NOVKOVIC = 'img/izveduvaci/329.jpg';
        const CRVENA_JABUKA = 'img/izveduvaci/339.jpg';
        const DADO_TOPIC = 'img/izveduvaci/361.jpg';
        const DALEKA_OBALA = 'img/izveduvaci/363.jpg';
        const DANIJEL_POPOVIC = 'img/izveduvaci/364.jpg';
        const DANIJELA_MARTINOVIC = 'img/izveduvaci/365.jpg';
        const DARKO_DOMIJAN = 'img/izveduvaci/367.jpg';
        const DEJAN_CUKIC = 'img/izveduvaci/368.jpg';
        const DENIS_DENIS = 'img/izveduvaci/371.jpg';
        const DINO_DVORNIK = 'img/izveduvaci/377.jpg';
        const DINO_MERLIN = 'img/izveduvaci/382.jpg';
        const DIVLJE_JAGODE = 'img/izveduvaci/427.jpg';
        const DIVLJI_ANDJELI = 'img/izveduvaci/432.jpg';
        const DJAVOLI = 'img/izveduvaci/433.jpg';
        const DJORDJE_BALASEVIC = 'img/izveduvaci/439.jpg';
        const DORIAN_GRAY = 'img/izveduvaci/466.jpg';
        const DORIS_DRAGOVIC = 'img/izveduvaci/467.jpg';
        const DRAGAN_STOJNIC = 'img/izveduvaci/949.jpg';
        const DRAZEN_ZECIC = 'img/izveduvaci/478.jpg';
        const DRUGI_NACIN = 'img/izveduvaci/479.jpg';
        const EKATERINA_VELIKA = 'img/izveduvaci/481.jpg';
        const ELEKTRICNI_ORGAZAM = 'img/izveduvaci/486.jpg';
        const ELVIRA_RAHIC = 'img/izveduvaci/492.jpg';
        const FAMILIJA = 'img/izveduvaci/489.jpg';
        const FILM = 'img/izveduvaci/493.jpg';
        const FIT = 'img/izveduvaci/504.jpg';
        const FRANO_LASIC = 'img/izveduvaci/507.jpg';
        const FRKA = 'img/izveduvaci/825.jpg';
        const GABI_NOVAK = 'img/izveduvaci/509.jpg';
        const GALIJA = 'img/izveduvaci/552.jpg';
        const GENERACIJA_5 = 'img/izveduvaci/560.jpg';
        const GIBONNI = 'img/izveduvaci/512.jpg';
        const GRUPA_220 = 'img/izveduvaci/561.jpg';
        const HARI_MATA_HARI = 'img/izveduvaci/517.jpg';
        const HAUSTOR = 'img/izveduvaci/686.jpg';
        const IBRICA_JUSIC = 'img/izveduvaci/961.jpg';
        const IDOLI  = 'img/izveduvaci/562.jpg';
        const INDEXI = 'img/izveduvaci/647.jpg';
        const ITD_BAND = 'img/izveduvaci/692.jpg';
        const IZOLDA = 'img/izveduvaci/781.jpg';
        const JADRANKA_STOJAKOVIC = 'img/izveduvaci/648.jpg';
        const JAKARTA = 'img/izveduvaci/943.jpg';
        const JASNA_ZLOKIC = 'img/izveduvaci/651.jpg';
        const JOSIPA_LISAC = 'img/izveduvaci/774.jpg';
        const KALIOPI = 'img/izveduvaci/791.jpg';
        const KEMAL_MONTENO = 'img/izveduvaci/793.jpg';
        const KERBER = 'img/izveduvaci/800.jpg';
        const KICO_SLABINAC = 'img/izveduvaci/805.jpg';
        const KSENIJA_ERKER = 'img/izveduvaci/962.jpg';
        const LAKI_PINGVINI = 'img/izveduvaci/807.jpg';
        const LEB_I_SOL = 'img/izveduvaci/552.jpg';
        const LEO_MARTIN = 'img/izveduvaci/529.jpg';
        const LETECI_ODRED = 'img/izveduvaci/530.jpg';
        const MAGAZIN = 'img/izveduvaci/531.jpg';
        const MARINA_PERAZIC = 'img/izveduvaci/638.jpg';
        const MASSIMO_SAVIC = 'img/izveduvaci/576.jpg';
        const MERI_CETINIC = 'img/izveduvaci/577.jpg';
        const MERLIN = 'img/izveduvaci/964.jpg';
        const METAK = 'img/izveduvaci/639.jpg';
        const MIKI_JEVREMOVIC = 'img/izveduvaci/640.jpg';
        const MILADIN_SOBIC = 'img/izveduvaci/634.jpg';
        const MINEA = 'img/izveduvaci/642.jpg';
        const MIRZINO_JATO = 'img/izveduvaci/643.jpg';
        const MISO_KOVAC = 'img/izveduvaci/543.jpg';
        const NEDA_UKRADEN = 'img/izveduvaci/579.jpg';
        const NEKI_TO_VOLE_VRUCE = 'img/izveduvaci/580.jpg';
        const NENO_BELAN = 'img/izveduvaci/582.jpg';
        const NOVI_FOSILI = 'img/izveduvaci/586.jpg';
        const OKTOBAR_1864 = 'img/izveduvaci/601.jpg';
        const OLIVER_DRAGOJEVIC = 'img/izveduvaci/605.jpg';
        const OLIVER_MANDIC = 'img/izveduvaci/591.jpg';
        const OLIVERA_KATARINA = 'img/izveduvaci/957.jpg';
        const OSMI_PUTNIK = 'img/izveduvaci/952.jpg';
        const OSVAJACI = 'img/izveduvaci/658.jpg';
        const PARNI_VALJAK = 'img/izveduvaci/663.jpg';
        const PEDJA_D_BOY = 'img/izveduvaci/965.jpg';
        const PILOTI = 'img/izveduvaci/697.jpg';
        const PLAVI_ORKESTAR = 'img/izveduvaci/704.jpg';
        const POSLEDNJA_IGRA_LEPTIRA = 'img/izveduvaci/709.jpg';
        const PRLJAVO_KAZALISTE = 'img/izveduvaci/723.jpg';
        const PRO_ARTE = 'img/izveduvaci/713.jpg';
        const PSIHOMODO_POP = 'img/izveduvaci/712.jpg';
        const REGATA = 'img/izveduvaci/741.jpg';
        const REGINA = 'img/izveduvaci/948.jpg';
        const RIBLJA_CORBA = 'img/izveduvaci/742.jpg';
        const RIVA = 'img/izveduvaci/940.jpg';
        const SEVERINA = 'img/izveduvaci/955.jpg';
        const SMAK = 'img/izveduvaci/786.jpg';
        const SRDJAN_JUL = 'img/izveduvaci/788.jpg';
        const SREBRENA_KRILA = 'img/izveduvaci/783.jpg';
        const STIJENE = 'img/izveduvaci/868.jpg';
        const SUNCANA_STRANA_ULICE = 'img/izveduvaci/790.jpg';
        const TAJCI = 'img/izveduvaci/826.jpg';
        const TEREZA_KESOVIJA = 'img/izveduvaci/831.jpg';
        const TIFA = 'img/izveduvaci/870.jpg';
        const TIME = 'img/izveduvaci/823.jpg';
        const TONY_MONTANO = 'img/izveduvaci/833.jpg';
        const TUTTI_FRUTTI = 'img/izveduvaci/834.jpg';
        const U_SKRIPCU = 'img/izveduvaci/893.jpg';
        const VAJTA = 'img/izveduvaci/836.jpg';
        const VALENTINO = 'img/izveduvaci/838.jpg';
        const VAN_GOGH = 'img/izveduvaci/885.jpg';
        const VIDEOSEX = 'img/izveduvaci/840.jpg';
        const VIKTORIJA = 'img/izveduvaci/877.jpg';
        const VJESTICE = 'img/izveduvaci/843.jpg';
        const VLADO_KALEMBER = 'img/izveduvaci/882.jpg';
        const XENIA = 'img/izveduvaci/841.jpg';
        const YU_GRUPA = 'img/izveduvaci/842.jpg';
        const YU_ROCK_MISIJA = 'img/izveduvaci/850.jpg';
        const ZABRANJENO_PUSENJE = 'img/izveduvaci/851.jpg';
        const ZANA = 'img/izveduvaci/844.jpg';
        const ZDRAVKO_COLIC = 'img/izveduvaci/809.jpg';
        const ZELJKO_BEBEK = 'img/izveduvaci/925.jpg';
        const ZLATKO_PEJAKOVIC = 'img/izveduvaci/931.jpg';
        

        // треба да се стави препознавање на песна и промена во текст на DOM

        var artistRadio = info.artist.replace(/&apos;/g, '\'');
        if (artistRadio == 'FRATELLO') {var urlCoverArt = FRATELLO;}
        else if (artistRadio == 'STAVI PRAVU STVAR') {var urlCoverArt = STAVI_PRAVU_STVAR;}
        else if (artistRadio == 'STO SI U KAVU STAVILA') {var urlCoverArt = STO_SI_U_KAVU_STAVILA;}
        else if (artistRadio == 'OBICNA LJUBAVNA PJESMA') {var urlCoverArt = OBICNA_LJUBAVNA_PJESMA;}
        else if (artistRadio == 'A STA DA RADIM') {var urlCoverArt = A_STA_DA_RADIM;}
        else if (artistRadio == 'DIGNI ME VISOKO') {var urlCoverArt = DIGNI_ME_VISOKO;}
        else if (artistRadio == 'OTKAZAN LET') {var urlCoverArt = OTKAZAN_LET;}
        else if (artistRadio == 'LJUBAV PREKO ZIVE') {var urlCoverArt = LJUBAV_PREKO_ZICE;}
        else if (artistRadio == 'MIKI MIKI') {var urlCoverArt = MIKI_MIKI;}
        else if (artistRadio == 'DAO SAM TI DUSI') {var urlCoverArt = DAO_SAM_TI_DUSU;}
        else if (artistRadio == 'S TOBOM NASAO SAM SRECU') {var urlCoverArt = S_TOBOM_NASAO_SAM_SRECU;}
        else if (artistRadio == 'KESTENI') {var urlCoverArt = KESTENI;}
        else if (artistRadio == 'POSLE 9 GODINA') {var urlCoverArt = POSLE_9_GODINA;}
        else if (artistRadio == 'SANJA') {var urlCoverArt = SANJA;}
        else if (artistRadio == 'EJ STA MI RADIS') {var urlCoverArt = EJ_STA_MI_RADIS;}
        else if (artistRadio == 'NEK TI JUTRO MIRISE NA MENE') {var urlCoverArt = NEK_TI_JUTRO_MIRISE_NA_MENE;}
        else if (artistRadio == 'DOJDJI U 5 DO 5') {var urlCoverArt = DOJDJI_U_5_DO_5;}
        else if (artistRadio == 'ZEMLJO MOJA FT ISMETA KRAVAC') {var urlCoverArt = ZEMLJO_MOJA_FT_ISMETA_KRAVAC;}
        else if (artistRadio == 'ANDJELI NAS ZOVU DA IM SKINEMO KRILA') {var urlCoverArt = ANDJELI_NAS_ZOVU_DA_IM_SKINEMO_KRILA;}
        else if (artistRadio == 'O MLADOSTI') {var urlCoverArt = O_MLADOSTI;}
        else if (artistRadio == 'SVE STO ZNAS O MENI') {var urlCoverArt = SVE_STO_ZNAS_O_MENI;}
        else if (artistRadio == 'DEVOJKA IZ MOGA KRAJA') {var urlCoverArt = DEVOJKA_IZ_MOGA_KRAJA;}
        else if (artistRadio == 'PROLJECE BEZ TEBE') {var urlCoverArt = PROLJECE_BEZ_TEBE;}
        else if (artistRadio == 'ZAGRLI ME') {var urlCoverArt = ZAGRLI_ME;}
        else if (artistRadio == 'DEVOJKA BROJ 8') {var urlCoverArt = DEVOJKA_BROJ_8;}
        else if (artistRadio == 'PAKLENI VOZACI') {var urlCoverArt = PAKLENI_VOZACI;}
        else if (artistRadio == 'ZA LJUBAV TREBA IMAT DUSU') {var urlCoverArt = ZA_LJUBAV_TREBA_IMAT_DUSU;}
        else if (artistRadio == 'VOLJELA ME NIJE NI JEDNA') {var urlCoverArt = VOLJELA_ME_NIJE_NI_JEDNA;}
        else if (artistRadio == 'USNE VRELE VISNJE') {var urlCoverArt = USNE_VRELE_VISNJE;}
        else if (artistRadio == 'AKO ZNAS BILO STA') {var urlCoverArt = AKO_ZNAS_BILO_STA;}
        else if (artistRadio == 'BALKAN') {var urlCoverArt = BALKAN;}
        else if (artistRadio == 'GRACIJA') {var urlCoverArt = GRACIJA;}
        else if (artistRadio == 'MARINA') {var urlCoverArt = MARINA;}
        else if (artistRadio == 'LJEPE ZENE PROLAZE KROZ GRAD') {var urlCoverArt = LJEPE_ZENE_PROLAZE_KROZ_GRAD;}
        else if (artistRadio == 'NOC BEZ SNA') {var urlCoverArt = NOC_BEZ_SNA;}
        else if (artistRadio == 'DA TE VIDIM GOLU') {var urlCoverArt = DA_TE_VIDIM_GOLU;}
        else if (artistRadio == 'SAMO NAM JE LJUBAV POTREBNA') {var urlCoverArt = SAMO_NAM_JE_LJUBAV_POTREBNA;}
        else if (artistRadio == 'PLAVI SAFIRU') {var urlCoverArt = PLAVI_SAFIRU;}
        else if (artistRadio == 'OD KADe TEBE VOLIM') {var urlCoverArt = OD_KAD_TEBE_VOLIM;}
        else if (artistRadio == 'VERUJEM NE VERUJEM') {var urlCoverArt = VERUJEM_NE_VERUJEM;}
        else if (artistRadio == 'GODINE PROLAZE') {var urlCoverArt = GODINE_PROLAZE;}
        else if (artistRadio == 'TISINA') {var urlCoverArt = TISINA;}
        else if (artistRadio == 'RUSKI VOZ') {var urlCoverArt = RUSKI_VOZ;}
        else if (artistRadio == 'VESELA PESMA') {var urlCoverArt = VESELA_PESMA;}
        else if (artistRadio == 'ZIVOT JE NEKAD SIV NEKAD ZUT') {var urlCoverArt = ZIVOT_JE_NEKAD_SIV_NEKAD_ZUT;}
        else if (artistRadio == 'GORE DOLE') {var urlCoverArt = GORE_DOLE;}
        else if (artistRadio == 'TI SE LJUBIS') {var urlCoverArt = TI_SE_LJUBIS;}
        else if (artistRadio == 'SA DRUGE STRANE') {var urlCoverArt = SA_DRUGE_STRANE;}
        else if (artistRadio == 'ZAZMURI') {var urlCoverArt = ZAZMURI;}
        else if (artistRadio == 'DO BEOGRADA') {var urlCoverArt = DO_BEOGRADA;}
        else if (artistRadio == 'VIDI STA SAM TI URADIO OD PESME MAMA') {var urlCoverArt = VIDI_STA_SAM_TI_URADIO_OD_PESME_MAMA;}
        else if (artistRadio == 'SARENE PILULE') {var urlCoverArt = SARENE_PILULE;}
        else if (artistRadio == 'VEK') {var urlCoverArt = VEK;}
        else if (artistRadio == 'TAMARA') {var urlCoverArt = TAMARA;}
        else if (artistRadio == 'POLJUBI ME') {var urlCoverArt = POLJUBI_ME;}
        else if (artistRadio == 'LEPA JANJA RIBERAVA KCI') {var urlCoverArt = LEPA_JANJA_RIBAREVA_KCI;}
        else if (artistRadio == 'ZMAJ OD NOVAJA') {var urlCoverArt = ZMAJ_OD_NOCAJA;}
        else if (artistRadio == 'MUZIKA NA STRUJU') {var urlCoverArt = MUZIKA_NA_STRUJU;}
        else if (artistRadio == 'OVO JE BALKAN') {var urlCoverArt = OVO_JE_BALKAN;}
        else if (artistRadio == 'JOS TE VOLIM') {var urlCoverArt = JOS_TE_VOLIM;}
        else if (artistRadio == 'NA VRHOVIMA PRSTIJU') {var urlCoverArt = NA_VRHOVIMA_PRSTIJU;}
        else if (artistRadio == 'KAD HODAS') {var urlCoverArt = KAD_HODAS;}
        else if (artistRadio == 'MOJI SU DRUGOVI') {var urlCoverArt = MOJI_SU_DRUGOVI}
        else if (artistRadio == 'GDE SI') {var urlCoverArt = GDE_SI;}
        else if (artistRadio == 'BAM BAM BAM') {var urlCoverArt = BAM_BAM_BAM;}
        else if (artistRadio == 'NEKA SVEMIR CUJE NEMIR') {var urlCoverArt = NEKA_SVEMIR_CUJE_NEMIR;}
        else if (artistRadio == 'JEDINO TO SE ZOVE LJUBAV') {var urlCoverArt = JEDINO_TO_SE_ZOVE_LJUBAV;}
        else if (artistRadio == 'KRV SRECA SUZI I ZNOJ') {var urlCoverArt = KRV_SRECA_SUZE_I_ZNOJ;}
        else if (artistRadio == 'RUDI') {var urlCoverArt = RUDI;}
        else if (artistRadio == 'BRAZIL') {var urlCoverArt = BRA_ZIL;}
        else if (artistRadio == 'HAJDE DA UZMEMO NEKI DOBAR AUTO') {var urlCoverArt = HAJDE_DA_UZMEMO_NEKI_DOBAR_AUTO;}
        else if (artistRadio == 'BADEMI I SO FT BAJAGA') {var urlCoverArt = BADEMI_I_SO_FT_BAJAGA;}
        else if (artistRadio == 'DA PRICAMO O LJUBAVU') {var urlCoverArt = DA_PRICAMO_O_LJUBAVI;}
        else if (artistRadio == 'IPAK POZELIM NEKO PISMO') {var urlCoverArt = IPAK_POZELIM_NEKO_PISMO;}
        else if (artistRadio == 'BITANGA I PRINCEZA') {var urlCoverArt = BITANGA_I_PRINCEZA;}
        else if (artistRadio == 'SVE CE TO MILA MOJA PREKRTITI RUZMARIN') {var urlCoverArt = SVE_CE_TO_MILA_MOJA_PREKRITI_RUZMARIN;}
        else if (artistRadio == 'NOCAS JE KO LUBENICA') {var urlCoverArt = NOCAS_JE_KO_LUBENICA;}
        else if (artistRadio == 'PLJUNI I ZAPEVAJ MOJA JUGOSLAVIJO') {var urlCoverArt = PLJUNI_I_ZAPEVAJ_MOJA_JUGOSLAVIJO;}
        else if (artistRadio == 'A I TI ME IZNEVJERI') {var urlCoverArt = A_I_TI_ME_IZNEVJERI;}
        else if (artistRadio == 'RUZICA SI BILA') {var urlCoverArt = RUZICA_SI_BILA;}
        else if (artistRadio == 'HAJDEMO U PLANINE') {var urlCoverArt = HAJDEMO_U_PLANINE;}
        else if (artistRadio == 'JER KAD OSTARIS') {var urlCoverArt = JER_KAD_OSTARIS;}
        else if (artistRadio == 'LAZES ZLATO') {var urlCoverArt = LAZES_ZLATO;}
        else if (artistRadio == 'ZA ESMU') {var urlCoverArt = ZA_ESMU;}
        else if (artistRadio == 'LIPE CVATU') {var urlCoverArt = LIPE_CVATU;}
        else if (artistRadio == 'PADAJU ZVEZDE') {var urlCoverArt = PADAJU_ZVEZDE;}
        else if (artistRadio == 'DA TE BOFDO NEVOLIM') {var urlCoverArt = DA_TE_BOGDO_NEVOLIM;}
        else if (artistRadio == 'MENI SE NESPAVA') {var urlCoverArt = MENI_SE_NESPAVA;}
        else if (artistRadio == 'AKO MOZES ZABORAVI') {var urlCoverArt = AKO_MOZES_ZABORAVI;}
        else if (artistRadio == 'U VREME OTKAZANIH LETOVA') {var urlCoverArt = U_VREME_OTKAZANIH_LETOVA;}
        else if (artistRadio == 'DOZIVJETI STOTU') {var urlCoverArt = DOZIVJETI_STOTU;}
        else if (artistRadio == 'ZAZMURI I BROJ DO 100') {var urlCoverArt = ZAZMURI_I_BROJ_DO_100;}
        else if (artistRadio == 'PRISTAO SAM BICU SVE STO HOCE') {var urlCoverArt = PRISTAO_SAM_BICU_SVE_STO_HOCE;}
        else if (artistRadio == 'HA HA HA SVI MARS NA PLJES') {var urlCoverArt = HA_HA_HA_SVI_MARS_NA_PLJES;}
        else if (artistRadio == 'KAD BI BIO BIJELO DUGME') {var urlCoverArt = KAD_BI_BIO_BIJELO_DUGME;}
        else if (artistRadio == 'SELMA') {var urlCoverArt = SELMA;}
        else if (artistRadio == 'IMA NEKA TAJNA VEZA') {var urlCoverArt = IMA_NEKA_TAJNA_VEZA;}
        else if (artistRadio == 'DA SAM PEKAR') {var urlCoverArt = DA_SAM_PEKAR;}
        else if (artistRadio == 'NE SPAVAJ MALA MOJA MUZIKA DOK SVIRA') {var urlCoverArt = NE_SPAVAJ_MALA_MOJA_MUZIKA_DOK_SVIRA;}
        else if (artistRadio == 'AKO IMA BOGA') {var urlCoverArt = AKO_IMA_BOGA;}
        else if (artistRadio == 'NAPILE SE ULICE') {var urlCoverArt = NAPILE_SE_ULICE;}
        else if (artistRadio == 'STA IMA NOVO') {var urlCoverArt = STA_IMA_NOVO;}
        else if (artistRadio == 'NAKON SVIH OVIH GODINA') {var urlCoverArt = NAKON_SVIH_OVIH_GODINA;}
        else if (artistRadio == 'CIRIBIRIBELA') {var urlCoverArt = CIRIBIRIBELA;}
        else if (artistRadio == 'DJURDJEVDAN') {var urlCoverArt = DJURDJEVDAN;}
        else if (artistRadio == 'EVO ZAKLECU SE') {var urlCoverArt = EVO_ZAKLECU_SE;}
        else if (artistRadio == 'IZGLEDALA JE MALO CUDNO U KAPUTU') {var urlCoverArt = IZGLEDALA_JE_MALO_CUDNO_U_KAPUTU;}
        else if (artistRadio == 'LOSE VINO') {var urlCoverArt = LOSE_VINO;}
        else if (artistRadio == 'SANJAO SAM NOCAS DA TE NEMAM') {var urlCoverArt = SANJAO_SAM_NOCAS_DA_TE_NEMAM;}
        else if (artistRadio == 'NA ZADNJEM SEDISTU MOGA AUTA') {var urlCoverArt = NA_ZADNJEM_SEDISTU_MOGA_AUTA;}
        else if (artistRadio == 'SVI MARS NA PLES') {var urlCoverArt = SVI_MARS_NA_PLES;}
        else if (artistRadio == 'TAKO TI JE MALA MOJA') {var urlCoverArt = TAKO_TI_JE_MALA_MOJA;}
        else if (artistRadio == 'DOBRO VAM JUTRO') {var urlCoverArt = DOBRO_VAM_JUTRO;}
        else if (artistRadio == 'ZLATNI DAN') {var urlCoverArt = ZLATNI_DAN;}
        else if (artistRadio == 'MILO MOJE') {var urlCoverArt = MILO_MOJE;}
        else if (artistRadio == 'UZALUD ME PODSECAS') {var urlCoverArt = UZALUD_ME_PODSECAS;}
        else if (artistRadio == 'STO JE SA PRINCEZOM MOJE VRELE MLADOSTI') {var urlCoverArt = STO_JE_SA_PRINCEZOM_MOJE_VRELE_MLADOSTI;}
        else if (artistRadio == 'KO SAM BEZ TEBE') {var urlCoverArt = KO_SAM_BEZ_TEBE;}
        else if (artistRadio == 'EMILY') {var urlCoverArt = EMILY;}
        else if (artistRadio == 'KUDA IDU IZGUBLJENE DEVOJKE') {var urlCoverArt = KUDA_IDU_IZGUBLJENE_DEVOJKE;}
        else if (artistRadio == 'PRODALA ME TI') {var urlCoverArt = PRODALA_ME_TI;}
        else if (artistRadio == 'DOK SVIRA RADIO') {var urlCoverArt = DOK_SVIRA_RADIO;}
        else if (artistRadio == 'DALEKO FT KEMALMONTENO') {var urlCoverArt = DALEKO_FT_KEMALMONTENO;}
        else if (artistRadio == 'MI SMO JACI I OD SUDBINE') {var urlCoverArt = MI_SMO_JACI_I_OD_SUDBINE;}
        else if (artistRadio == 'U DOBRU I ZLU') {var urlCoverArt = U_DOBRU_I_ZLU;}
        else if (artistRadio == 'ELOIS') {var urlCoverArt = ELOIS;}
        else if (artistRadio == 'TUGA TI I JA') {var urlCoverArt = TUGA_TI_I_JA;}
        else if (artistRadio == 'TO MI RADI') {var urlCoverArt = TO_MI_RADI;}
        else if (artistRadio == 'NEKAKO S PROLJECA FT KEMAL MONTENO') {var urlCoverArt = NEKAKO_S_PROLJECA_FT_KEMAL_MONTENO;}
        else if (artistRadio == 'MOJE NEJMILIJE') {var urlCoverArt = MOJE_NAJMILIJE;}
        else if (artistRadio == 'TUGO NESRECO') {var urlCoverArt = TUGO_NESRECO;}
        else if (artistRadio == 'ZOVU NAS ULICE') {var urlCoverArt = ZOVU_NAS_ULICE;}
        else if (artistRadio == 'BJEZI KISO S PROZORA') {var urlCoverArt = BJEZI_KISO_S_PROZORA;}
        else if (artistRadio == 'TAMO GDE LJUBAV POCINJE') {var urlCoverArt = TAMO_GDE_LJUBAV_POCINJE;}
        else if (artistRadio == 'TVOGA SRCA VRATA') {var urlCoverArt = TVOGA_SRCA_VRATA;}
        else if (artistRadio == 'DIRLIJA') {var urlCoverArt = DIRLIJA;}
        else if (artistRadio == 'IMAM NEKE FORE') {var urlCoverArt = IMAM_NEKE_FORE;}
        else if (artistRadio == 'VOLIO BI DA SI TU') {var urlCoverArt = VOLIO_BI_DA_SI_TU;}
        else if (artistRadio == 'SAMPANJSKI POLJUBAC') {var urlCoverArt = SAMPANJSKI_POLJUBAC;}
        else if (artistRadio == 'DA MI JE DO NJE') {var urlCoverArt = DA_MI_JE_DO_NJE;}
        else if (artistRadio == 'STIZU ME SECANJA') {var urlCoverArt = STIZU_ME_SECANJA;}
        else if (artistRadio == 'IMA NESTO OD SRCA DO SRCA') {var urlCoverArt = IMA_NESTO_OD_SRCA_DO_SRCA;}
        else if (artistRadio == 'AKO AKO') {var urlCoverArt = AKO_AKO;}
        else if (artistRadio == 'SVIDJA MI SE OVA STVAR') {var urlCoverArt = SVIDJA_MI_SE_OVA_STVAR;}
        else if (artistRadio == 'PRINCIPESSA') {var urlCoverArt = PRINCIPESSA;}
        else if (artistRadio == 'NEMA VISE VREMENA') {var urlCoverArt = NEMA_VISE_VREMENA;}
        else if (artistRadio == 'S TVOJIH USANA') {var urlCoverArt = S_TVOJIH_USANA;}
        else if (artistRadio == 'FLOYD') {var urlCoverArt = FLOYD;}
        else if (artistRadio == 'JA HOCU ZIVOT') {var urlCoverArt = JA_HOCU_ZIVOT;}
        else if (artistRadio == 'NOC JE PREKRASNA') {var urlCoverArt = NOC_JE_PREKRASNA;}
        else if (artistRadio == 'DZULI') {var urlCoverArt = DZULI;}
        else if (artistRadio == 'NEKA MI NE SVANE') {var urlCoverArt = NEKA_MI_NE_SVANE;}
        else if (artistRadio == 'DA JE SALDJE ZASPATI') {var urlCoverArt = DA_JE_SALDJE_ZASPATI;}
        else if (artistRadio == 'ULICA JORGOVANA') {var urlCoverArt = ULICA_JORGOVANA;}
        else if (artistRadio == 'JA BIH DA PEVAM') {var urlCoverArt = JA_BIH_DA_PEVAM;}
        else if (artistRadio == 'JULIJA') {var urlCoverArt = JULIJA;}
        else if (artistRadio == 'LETNJE KISE') {var urlCoverArt = LETNJE_KISE;}
        else if (artistRadio == 'OAZA SNOVA') {var urlCoverArt = OAZA_SNOVA;}
        else if (artistRadio == 'SOBA 23') {var urlCoverArt = SOBA_23;}
        else if (artistRadio == 'PROGRAM TVOG KOMPJUTERA') {var urlCoverArt = PROGRAM_TVOG_KOMPJUTERA;}
        else if (artistRadio == 'VOLI ME JOS OVU NOC') {var urlCoverArt = VOLI_ME_JOS_OVU_NOC;}
        else if (artistRadio == 'JA SAM LAZLJIVA') {var urlCoverArt = JA_SAM_LAZLJIVA;}
        else if (artistRadio == 'U RITMU ME OKRENI') {var urlCoverArt = U_RITMU_ME_OKRENI;}
        else if (artistRadio == 'TI SI MI U MISLIMA') {var urlCoverArt = TI_SI_MI_U_MISLIMA;}
        else if (artistRadio == 'TEBI PRIPADAM') {var urlCoverArt = TEBI_PRIPADAM;}
        else if (artistRadio == 'LJUBAV SE ZOVE IMENOM TVOIM') {var urlCoverArt = LJUBAV_SE_ZOVE_IMENOM_TVOIM;}
        else if (artistRadio == 'NECU DA ZNAM ZA NIKOG OSIM TEBE') {var urlCoverArt = NECU_DA_ZNAM_ZA_NIKOG_OSIM_TEBE;}
        else if (artistRadio == 'JACE MANIJACE') {var urlCoverArt = JACE_MANIJACE;}
        else if (artistRadio == 'UMRI PRIJE SMRTI') {var urlCoverArt = UMRI_PRIJE_SMRTI;}
        else if (artistRadio == 'SREDINOM') {var urlCoverArt = SREDINOM;}
        else if (artistRadio == 'MOJ JE ZIVOT SVICARSKA') {var urlCoverArt = MOJ_JE_ZIVOT_SVICARSKA;}
        else if (artistRadio == 'SVE JE LAZ') {var urlCoverArt = SVE_JE_LAZ;}
        else if (artistRadio == 'GODINAMA') {var urlCoverArt = GODINAMA;}
        else if (artistRadio == 'KAD SI REKLA DA ME VOLIS') {var urlCoverArt = KAD_SI_REKLA_DA_ME_VOLIS;}
        else if (artistRadio == 'HITNA') {var urlCoverArt = HITNA;}
        else if (artistRadio == 'DA JE TUGA SNIJEG') {var urlCoverArt = DA_JE_TUGA_SNIJEG;}
        else if (artistRadio == 'KREMEN') {var urlCoverArt = KREMEN;}
        else if (artistRadio == 'KAD COVIJEK VOLI ZENU') {var urlCoverArt = KAD_COVIJEK_VOLI_ZENU;}
        else if (artistRadio == 'STA TI ZNACIM JA') {var urlCoverArt = STA_TI_ZNACIM_JA;}
        else if (artistRadio == 'DANAS SAM OK') {var urlCoverArt = DANAS_SAM_OK;}
        else if (artistRadio == 'BOSNOM BEHAR PROBEHARO') {var urlCoverArt = BOSNOM_BEHAR_PROBEHARAO;}
        else if (artistRadio == 'OBICNA LJUBAVNA PJESMA') {var urlCoverArt = OBICNA_LJUBAVNAPJESMA;}
        else if (artistRadio == 'A STA DA RADIM') {var urlCoverArt = ASTA_DA_RADIM;}
        else if (artistRadio == 'DIGNI ME VISOKO') {var urlCoverArt = DIGNI_MEVISOKO;}
        else if (artistRadio == 'FRATELLO') {var urlCoverArt = FRAT_ELLO;}
        else if (artistRadio == 'STAVI PRAVU STVAR') {var urlCoverArt = STAVI_PRAVUSTVAR;}
        else if (artistRadio == 'STA SI MI U KAVU STAVILA') {var urlCoverArt = STA_SI_MI_UKAVU_STAVILA;}
        else if (artistRadio == 'NESTO LIJEPO TREBA DA SE DESI') {var urlCoverArt = NESTO_LIJEPO_TREBA_DA_SE_DESI;}
        else if (artistRadio == 'MJESECINA') {var urlCoverArt = MJESECINA;}
        else if (artistRadio == 'JEL SARAJEVO GDE JE NEKAD BILO') {var urlCoverArt = JEL_SARAJEVO_GDE_JE_NEKAD_BILO;}
        else if (artistRadio == 'KAD ZAMIRISU JORGOVANI FT VESNA ZMIJANAC') {var urlCoverArt = KADZAMIRISUJORGOVANIFTVESNA_ZMIJANAC;}
        else if (artistRadio == 'ZAR JE TO SVE STO IMAM OD TEBE') {var urlCoverArt = ZAR_JE_TO_SVE_STO_IMAM_OD_TEBE;}
        else if (artistRadio == 'JA POTPUNO TRIJEZAN UMIREM') {var urlCoverArt = JA_POTPUNO_TRIJEZAN_UMIREM;}
        else if (artistRadio == 'NE ZOVI ME NA GRIJEH') {var urlCoverArt = NE_ZOVI_ME_NA_GRIJEH;}
        else if (artistRadio == 'NEMA JA 18 GODINA') {var urlCoverArt = NEMAM_JA_18_GODINA;}
        else if (artistRadio == 'KOKUZNA VREMENA') {var urlCoverArt = KOKUZNA_VREMENA;}
        else if (artistRadio == 'JA SAM NA TE NAVIKO') {var urlCoverArt = JA_SAM_NA_TE_NAVIKO;}
        else if (artistRadio == 'UCINI MI PRAVU STVAR') {var urlCoverArt = UCINI_MI_PRAVU_STVAR;}
        else if (artistRadio == 'SA MOJIH USANA') {var urlCoverArt = SA_MOJIH_USANA;}
        else if (artistRadio == 'DA SUTIS') {var urlCoverArt = DA_SUTIS;}
        else if (artistRadio == 'OTKRIT CU TI TAJNU') {var urlCoverArt = OTKRIT_CU_TI_TAJNU;}
        else if (artistRadio == 'DESET MLADJA') {var urlCoverArt = DESET_MLADJA;}
        else if (artistRadio == 'OSTAT CE ISTINE DVIJE') {var urlCoverArt = OSTAT_CE_ISTINE_DVIJE;}
        else if (artistRadio == 'AKO ME IKAD SRETNES') {var urlCoverArt = AKO_ME_IKADA_SRETNES;}
        else if (artistRadio == 'ZABORAVI') {var urlCoverArt = ZABORAVI;}
        else if (artistRadio == 'MOJA BOGDA SNA') {var urlCoverArt = MOJA_BOGDA_SNA;}
        else if (artistRadio == 'BASKA TI') {var urlCoverArt = BASKA_TI;}
        else if (artistRadio == 'SMIJEHOM STAH POKRIJEM') {var urlCoverArt = SMIJEHOM_STRAH_POKRIJEM;}
        else if (artistRadio == 'NEK PADAJU CUSKIJE') {var urlCoverArt = NEK_PADAJU_CUSKIJE;}
        else if (artistRadio == 'ISPOCETKA') {var urlCoverArt = ISPOCETKA;}
        else if (artistRadio == 'SVE DOK TE BUDE IMALO') {var urlCoverArt = SVE_DOK_TE_BUDE_IMALO;}
        else if (artistRadio == 'LAZU ME') {var urlCoverArt = LAZU_ME;}
        else if (artistRadio == 'LELO') {var urlCoverArt = LELO;}
        else if (artistRadio == 'TREBAM TE MARIJA') {var urlCoverArt = TREBAM_TE_MARIJA;} 
        else if (artistRadio == 'KAKO SI TOPLA I MILA') {var urlCoverArt = KAKO_SI_TOPLA_I_MILA;}
        else if (artistRadio == 'KRIVO JE MORE') {var urlCoverArt = KRIVO_JE_MORE;}
        else if (artistRadio == 'JEDINA MOJA') {var urlCoverArt = JEDINA_MOJA;}
        else if (artistRadio == 'ZAUVJEK TVOJ') {var urlCoverArt = ZAUVJEK_TVOJ;}
        else if (artistRadio == 'VOL TE TVOJA ZVER') {var urlCoverArt = VOLI_TE_TVOJA_ZVER;}
        else if (artistRadio == 'OSTAVI UZ MENE') {var urlCoverArt = OSTANI_UZ_MENE;}
        else if (artistRadio == 'BAMBINA') {var urlCoverArt = BAMBINA;}
        else if (artistRadio == 'DANI LJUBAVI') {var urlCoverArt = DANI_LJUBAVI;}
        else if (artistRadio == 'IVONA') {var urlCoverArt = IVONA;}
        else if (artistRadio == 'JAGODE I COKOLADA') {var urlCoverArt = JAGODE_I_COKOLADA;}
        else if (artistRadio == 'PRICAJ MI O LJUBAVI') {var urlCoverArt = PRICAJ_MI_O_LJUBAVI;}
        else if (artistRadio == 'ANDJELA MOJA JE DRAGA VESTICA') {var urlCoverArt = ANDJELA_MOJA_JE_DRAGA_VESTICA;}
        else if (artistRadio == 'BOZA ZVANI PUB') {var urlCoverArt = BOZA_ZVANI_PUB;}
        else if (artistRadio == 'DEVOJKA SA CARDAS NOGAMA') {var urlCoverArt = DEVOJKA_SA_CARDAS_NOGAMA;}
        else if (artistRadio == 'DIVLJI BADEM') {var urlCoverArt = DIVLJI_BADEM;}
        else if (artistRadio == 'D MOLL') {var urlCoverArt = D_MOLL;}
        else if (artistRadio == 'JA LUZER') {var urlCoverArt = JA_LUZER;}
        else if (artistRadio == 'JAROSLOAVA PRINCEZO JAVI SE') {var urlCoverArt = JAROSLAVA_PRINCEZO_JAVI_SE;}
        else if (artistRadio == 'LEPA PROTINA KCI') {var urlCoverArt = LEPA_PROTINA_KCI;}
        else if (artistRadio == 'LJERKA') {var urlCoverArt = LJERKA;}
        else if (artistRadio == 'NE LOMITE MI BAGRENJE') {var urlCoverArt = NE_LOMITE_MI_BAGRENJE;}
        else if (artistRadio == 'NE VOLIM JANUAR') {var urlCoverArt = NE_VOLIM_JANUAR;}
        else if (artistRadio == 'NEKI NOVI KLINCI') {var urlCoverArt = NEKI_NOVI_KLINCI;}
        else if (artistRadio == 'NEVERNIK') {var urlCoverArt = NEVERNIK;}
        else if (artistRadio == 'NIKAD KAO BANE') {var urlCoverArt = NIKAD_KAO_BANE;}
        else if (artistRadio == 'OLELOLE') {var urlCoverArt = OLELOLE;}
        else if (artistRadio == 'OPROSTI MI KARTIN') {var urlCoverArt = OPROSTI_MI_KATRIN;}
        else if (artistRadio == 'PA DOBRO GDE SI TI') {var urlCoverArt = PA_DOBRO_GDE_SI_TI;}
        else if (artistRadio == 'PORTRET MOG ZIVOTA') {var urlCoverArt = PORTRET_MOG_ZIVOTA;}
        else if (artistRadio == 'PROVINCIJALKA') {var urlCoverArt = PROVINCIJALKA;}
        else if (artistRadio == 'PRVA LJUBAV') {var urlCoverArt = PRVA_LJUBAV;}
        else if (artistRadio == 'RINGISPIL') {var urlCoverArt = RINGISPIL;}
        else if (artistRadio == 'SIN JEDINAC') {var urlCoverArt = SIN_JEDINAC;}
        else if (artistRadio == 'SLABO DIVANIM MADZARSKI') {var urlCoverArt = SLABO_DIVANIM_MADZARSKI;}
        else if (artistRadio == 'SLOVENSKA') {var urlCoverArt = SLOVENSKA;}
        else if (artistRadio == 'SVIRAJTE MI JESEN STIZE DUNJO MOJA') {var urlCoverArt = SVIRAJTE_MI_JESEN_STIZE_DUNJO_MOJA;}
        else if (artistRadio == 'USPAVANKA ZA DECAKA') {var urlCoverArt = USPAVANKA_ZA_DECAKA;}
        else if (artistRadio == 'OLIVERA') {var urlCoverArt = OLIVERA;}
        else if (artistRadio == 'SJAJ U TAMI') {var urlCoverArt = SJAJ_U_TAMI;}
        else if (artistRadio == 'SAKOM O STOL') {var urlCoverArt = SAKOM_O_STOL;}
        else if (artistRadio == 'JA NOCAS UMIREM') {var urlCoverArt = JA_NOCAS_UMIREM;}
        else if (artistRadio == 'KRIVI LJUDI') {var urlCoverArt = KRIVI_LJUDI;}
        else if (artistRadio == 'MALO MI ZA SRICU TRIBA') {var urlCoverArt = MALO_MI_ZA_SRICU_TRIBA;}
        else if (artistRadio == 'MARIJA MAGDALENA') {var urlCoverArt = MARIJA_MAGDALENA;}
        else if (artistRadio == 'MORAM') {var urlCoverArt = MORAM;}
        else if (artistRadio == 'PETAK') {var urlCoverArt = PETAK;}
        else if (artistRadio == 'TO') {var urlCoverArt = TO;}
        else if (artistRadio == 'ZELJO MOJA') {var urlCoverArt = ZELJO_MOJA;}
        else if (artistRadio == 'NI DA MORA NESTANE') {var urlCoverArt = NI_DA_MORA_NESTANE;}
        else if (artistRadio == 'STAJE OD MENE OSTALO') {var urlCoverArt = STAJE_OD_MENE_OSTALO;}
        else if (artistRadio == 'IMA LI NADE ZA NAS FT ANDJELA ZECIC') {var urlCoverArt = IMA_LI_NADE_ZA_NAS_FT_ANDJELA_ZECIC;}
        else if (artistRadio == 'PISI MI') {var urlCoverArt = PISI_MI;}
        else if (artistRadio == 'PRODJE OVAJ DAN') {var urlCoverArt = PRODJE_OVAJ_DAN;}
        else if (artistRadio == 'PAR GODINA ZA NAS') {var urlCoverArt = PAR_GODINA_ZA_NAS;}
        else if (artistRadio == 'SRCE') {var urlCoverArt = SRCE;}
        else if (artistRadio == 'OCI BOJE MEDA') {var urlCoverArt = OCI_BOJE_MEDA;}
        else if (artistRadio == 'TI SI SAM MOJ BOL') {var urlCoverArt = TI_SI_SAV_MOJ_BOL;}
        else if (artistRadio == 'KURG') {var urlCoverArt = KRUG;}
        else if (artistRadio == 'DA SI TAKO JAKA') {var urlCoverArt = DA_SI_TAKO_JAKA;}
        else if (artistRadio == 'BEJBE TI NISI TU') {var urlCoverArt = BEJBE_TI_NISI_TU;}
        else if (artistRadio == 'IGRA ROCK NN ROLL CELA JUGOSLAVIJA') {var urlCoverArt = IGRA_ROCK_NN_ROLL_CELA_JUGOSLAVIJA;}
        else if (artistRadio == 'MALA MALA MALA GRUPA PEDERA') {var urlCoverArt = MALA_MALA_MALA_GRUPA_PEDERA;}
        else if (artistRadio == 'PARANOJA') {var urlCoverArt = PARANOJA;}
        else if (artistRadio == 'STO JA VOLIM TAJ SEX') {var urlCoverArt = STO_JA_VOLIM_TAJ_SEX;}
        else if (artistRadio == 'A SADA IDEM FT TIFA') {var urlCoverArt = A_SADA_IDEM_FT_TIFA;}
        else if (artistRadio == 'BOJE SU U NAMA') {var urlCoverArt = BOJE_SU_U_NAMA;}
        else if (artistRadio == 'DOCI CU TI U SNOVIMA') {var urlCoverArt = DOCI_CU_TI_U_SNOVIMA;}
        else if (artistRadio == 'LIJEPO LIJEPO NEOPISIVO') {var urlCoverArt = LIJEPO_LIJEPO_NEOPISIVO;}
        else if (artistRadio == 'NJEZNO NJEZNO NJEZNIJE') {var urlCoverArt = NJEZNO_NJEZNO_NJEZNIJE;}
        else if (artistRadio == 'PJEVAMO DO ZORE') {var urlCoverArt = PJEVAJMO_DO_ZORE;}
        else if (artistRadio == 'ZAMISLI ZIVOT U RITMU MUZIKE ZA PLES') {var urlCoverArt = ZAMISLI_ZIVOT_U_RITMU_MUZIKE_ZA_PLES;}
        else if (artistRadio == 'DOBRE VIBRACIJE') {var urlCoverArt = DOBRE_VIBRACIJE;}
        else if (artistRadio == 'SRCE NA CESTI') {var urlCoverArt = SRCE_NA_CESTI;}
        else if (artistRadio == 'MI NISMO SAMI') {var urlCoverArt = MI_NISMO_SAMI;}
        else if (artistRadio == 'SJECAM SE PRVOG POLJUPCA') {var urlCoverArt = SJECAM_SE_PRVOG_POLJUPCA;}
        else if (artistRadio == 'LJUBAV JE ZAKON') {var urlCoverArt = LJUBAV_JE_ZAKON;}
        else if (artistRadio == 'MACKA') {var urlCoverArt = MACKA;}
        else if (artistRadio == 'ZABORAVIT CU SVE') {var urlCoverArt = ZABORAVIT_CU_SVE;}
        else if (artistRadio == 'ZVONI TELEFON') {var urlCoverArt = ZVONI_TELEFON;}
        else if (artistRadio == 'VOLIM TE BUDALO MALA') {var urlCoverArt = VOLIM_TE_BUDALO_MALA;}
        else if (artistRadio == 'ZAGRLJENI') {var urlCoverArt = ZAGRLJENI;}
        else if (artistRadio == 'PAMTIM SAMO SRETNE DANE') {var urlCoverArt = PAMTIM_SAMO_SRETNE_DANE;}
        else if (artistRadio == 'ON ME VOLI NA SVOJ NACIN') {var urlCoverArt = ON_ME_VOLI_NA_SVOJ_NACIN;}
        else if (artistRadio == 'VINO I GITARE') {var urlCoverArt = VINO_I_GITARE;}
        else if (artistRadio == 'CINIM PRAVU STVAR') {var urlCoverArt = CINIM_PRAVU_STVAR;}
        else if (artistRadio == 'DVIJE DUSE') {var urlCoverArt = DVIJE_DUSE;}
        else if (artistRadio == 'ISPOD MOGA PRAMCA') {var urlCoverArt = ISPOD_MOGA_PRAMCA;}
        else if (artistRadio == 'OVO MI JE SKOLA') {var urlCoverArt = OVO_MI_JE_SKOLA;}
        else if (artistRadio == 'SUVISE SAM NJEN') {var urlCoverArt = SUVISE_SAM_NJEN;}
        else if (artistRadio == 'BAS TI LIJEPO STOJE SUZE') {var urlCoverArt = BAS_TI_LIJEPO_STOJE_SUZE;}
        else if (artistRadio == 'HEJ KAKO SI') {var urlCoverArt = HEJ_KAKO_SI;}
        else if (artistRadio == 'JAVI SE') {var urlCoverArt = JAVI_SE;}
        else if (artistRadio == 'KAD DODJE OKTOBAR') {var urlCoverArt = KAD_DODJE_OKTOBAR;}
        else if (artistRadio == 'KAO DOMINE') {var urlCoverArt = KAO_DOMINE;}
        else if (artistRadio == 'COVAM NOC OD BUDNIH') {var urlCoverArt = CUVAM_NOC_OD_BUDNIH;}
        else if (artistRadio == 'FEMME FATALE') {var urlCoverArt = FEMME_FATALE;}
        else if (artistRadio == 'KAO KAKAO') {var urlCoverArt = KAO_KAKAO;}
        else if (artistRadio == 'MAMURNI LJUDI') {var urlCoverArt = MAMURNI_LJUDI;}
        else if (artistRadio == 'SKOPJE') {var urlCoverArt = SKOPJE;}
        else if (artistRadio == 'UCI ME MAJKO KARAJ ME') {var urlCoverArt = UCI_ME_MAJKO_KARAJ_ME;}
        else if (artistRadio == 'CUKNI VO DRVO') {var urlCoverArt = CUKNI_VO_DRVO;}
        else if (artistRadio == 'IMA VREMENA') {var urlCoverArt = IMA_VREMENA;}
        else if (artistRadio == 'SANJAO SAM MOJ RUZICU') {var urlCoverArt= SANJAO_SAM_MOJ_RUZICU;}
        else if (artistRadio == 'GUTLJAJ VINA') {var urlCoverArt = GUTLJAJ_VINA;}
        else if (artistRadio == 'JEL ZBOG NJE') {var urlCoverArt = JEL_ZBOG_NJE;}
        else if (artistRadio == 'KOKOLO') {var urlCoverArt = KOKOLO;}
        else if (artistRadio == 'LJUBE SE DOBRI LOSI ZLI') {var urlCoverArt = LJUBE_SE_DOBRI_LOSI_ZLI;}
        else if (artistRadio == 'MINUT SRCA TVOG') {var urlCoverArt = MINUT_SRCA_TVOG;}
        else if (artistRadio == 'OKO MOJE SANJIVO') {var urlCoverArt = OKO_MOJE_SANJIVO;}
        else if (artistRadio == 'OPIJUM') {var urlCoverArt = OPIJUM;}
        else if (artistRadio == 'PUT PUTUJEM') {var urlCoverArt = PUT_PUTUJEM;}
        else if (artistRadio == 'RANO RANIJE') {var urlCoverArt = RANO_RANIJE;}
        else if (artistRadio == 'SUZE BISERNE') {var urlCoverArt = SUZE_BISERNE;}
        else if (artistRadio == 'SVE BI SEKE LJUBILE MORNAER') {var urlCoverArt = SVE_BI_SEKE_LJUBILE_MORNARE;}
        else if (artistRadio == 'TAMARA') {var urlCoverArt = TAMARA1;}
        else if (artistRadio == 'AKO ME OSTAVIS') {var urlCoverArt = AKO_ME_OSTAVIS;}
        else if (artistRadio == 'JA NEMAM VISE RAZLOGA DA ZIVIM') {var urlCoverArt = JA_NEMAM_VISE_RAZLOGA_DA_ZIVIM;}
        else if (artistRadio == 'JEDAN DAN ZIVOTA') {var urlCoverArt = JEDAN_DAN_ZIVOTA;}
        else if (artistRadio == 'JOS I DANAS TEKU SUZE JEDNE ZENE') {var urlCoverArt = JOS_I_DANAS_TEKU_SUZE_JEDNE_ZENE;}
        else if (artistRadio == 'MALO MI JE JEDAN ZIVOT S TOBOM') {var urlCoverArt = MALO_MI_JE_JEDAN_ZIVOT_S_TOBOM;}
        else if (artistRadio == 'NIKOGA NISAM VOLIO TAKO') {var urlCoverArt = NIKOGA_NISAM_VOLIO_TAKO;}
        else if (artistRadio == 'OSTALA SI UVIJEK ISTA') {var urlCoverArt = OSTALA_SI_UVIJEK_ISTA;}
        else if (artistRadio == 'SVI PEVAJU JA NE CUJEM') {var urlCoverArt = SVI_PEVAJU_JA_NE_CUJEM;}
        else if (artistRadio == 'TI SI PJESMA MOJE DUSE') {var urlCoverArt = TI_SI_PJESMA_MOJE_DUSE;}
        else if (artistRadio == 'DALI SI SPAVALA') {var urlCoverArt = DALI_SI_SPAVALA;}
        else if (artistRadio == 'DA ME NISI') {var urlCoverArt = DA_ME_NISI;}
        else if (artistRadio == 'DIGNI RUKU') {var urlCoverArt = DIGNI_RUKU;}
        else if (artistRadio == 'DODIRNI ME') {var urlCoverArt = DODIRNI_ME;}
        else if (artistRadio == 'KAD ME POGLEDAS') {var urlCoverArt = KAD_ME_POGLEDAS;}
        else if (artistRadio == 'KOTOR') {var urlCoverArt = KOTOR;}
        else if (artistRadio == 'SKADARSKA') {var urlCoverArt = SKADARSKA;}
        else if (artistRadio == 'TRUBE') {var urlCoverArt = TRUBE;}
        else if (artistRadio == 'TI SAMO BUDI DOVOLNO DALEKO') {var urlCoverArt = TI_SAMO_BUDI_DOVOLJNO_DALEKO;}
        else if (artistRadio == 'OSMIJEH') {var urlCoverArt = OSMIJEH;}
        else if (artistRadio == 'KENOZOIK') {var urlCoverArt = KENOZOIK;}
        else if (artistRadio == 'MALJCHIKI') {var urlCoverArt = MALJCHIKI;}
        else if (artistRadio == 'LEJLA') {var urlCoverArt = LEJLA;}
        else if (artistRadio == 'LUD SAM ZA TOBOM') {var urlCoverArt = LUD_SAM_ZA_TOBOM;}
        else if (artistRadio == 'NEK NEBO NAM SUDI') {var urlCoverArt = NEK_NEBO_NAM_SUDI;}
        else if (artistRadio == 'OSTAVI SUZE ZA KRAJ') {var urlCoverArt = OSTAVI_SUZE_ZA_KRAJ;}
        else if (artistRadio == 'OTKAD TEBE NEMA') {var urlCoverArt = OTKAD_TEBE_NEMA;}
        else if (artistRadio == 'RODJENA SI SAMO ZA MENE') {var urlCoverArt = RODJENA_SI_SAMO_ZA_MENE;}
        else if (artistRadio == 'STRAH ME DA TE VOLIM') {var urlCoverArt = STRAH_ME_DA_TE_VOLIM;}
        else if (artistRadio == 'SVE LJUBAVI SU TUZNE') {var urlCoverArt = SVE_LJUBAVI_SU_TUZNE;}
        else if (artistRadio == 'SVI MOJI DRUMOVI') {var urlCoverArt = SVI_MOJI_DRUMOVI;}
        else if (artistRadio == 'TI ZNAS SVE') {var urlCoverArt = TI_ZNAS_SVE;}
        else if (artistRadio == 'VOLIO BI DA TE NE VOLIM') {var urlCoverArt = VOLIO_BI_DA_TE_NE_VOLIM;}
        else if (artistRadio == 'STRANAC U NOCI') {var urlCoverArt = STRANAC_U_NOCI;}
        else if (artistRadio == 'POTRAZI ME U PREDGRADU') {var urlCoverArt = POTRAZI_ME_U_PREDGRADU;}
        else if (artistRadio == 'SAMO SIMPATIJA') {var urlCoverArt = SAMO_SIMPATIJA;}
        else if (artistRadio == 'ZORA JE') {var urlCoverArt = ZORA_JE;}
        else if (artistRadio == 'STO CE TAJ COVJEK TU') {var urlCoverArt = STO_CE_TAJ_COVJEK_TU;}
        else if (artistRadio == 'TESKA VREMENA PRIJATELJU MOJ') {var urlCoverArt = TESKA_VREMENA_PRIJATELJU_MOJ;}
        else if (artistRadio == 'DOTAKNI ME USNAMA') {var urlCoverArt = DOTAKNI_ME_USNAMA;}
        else if (artistRadio == 'RIJEKA SNOVA') {var urlCoverArt = RIJEKA_SNOVA;}
        else if (artistRadio == 'SUNCAN DAN') {var urlCoverArt = SUNCAN_DAN;}
        else if (artistRadio == 'KAVANNA FT FIUMENS') {var urlCoverArt = KAVANNA_FT_FIUMENS;}
        else if (artistRadio == 'NAJDRAZE MOJE') {var urlCoverArt = NAJDRAZE_MOJE;}
        else if (artistRadio == 'PLAVA KOSULJA') {var urlCoverArt = PLAVA_KOSULJA;}
        else if (artistRadio == 'SUTI MOJ DJECACE PLAVI') {var urlCoverArt = SUTI_MOJ_DJECACE_PLAVI;}
        else if (artistRadio == 'ZA DOBRA STARA VREMENA') {var urlCoverArt = ZA_DOBRA_STARA_VREMENA;}
        else if (artistRadio == 'ZNAM') {var urlCoverArt = ZNAM;}
        else if (artistRadio == 'BICU TVOJ') {var urlCoverArt = BICU_TVOJ;}
        else if (artistRadio == 'BOBANE') {var urlCoverArt= BOBANE;}
        else if (artistRadio == 'DODJE MI DA VRISNEM TVOJE IME') {var urlCoverArt = DODJE_MI_DA_VRISNEM_TVOJE_IME;}
        else if (artistRadio == 'NIJE ZA NJU') {var urlCoverArt = NIJE_ZA_NJU;}
        else if (artistRadio == 'ODLAZIM A VOLIM TE') {var urlCoverArt = ODLAZIM_A_VOLIM_TE;}
        else if (artistRadio == 'OSLONI SE NA MENE') {var urlCoverArt = OSLONI_SE_NE_MENE;}
        else if (artistRadio == 'PITAJU ME PITAJU') {var urlCoverArt = PITAJU_ME_PITAJU;}
        else if (artistRadio == 'POMAGAJTE DRUGOVI') {var urlCoverArt = POMAGAJTE_DRUGOVI;}
        else if (artistRadio == 'SMEJEM SE A PLAKAO BIH') {var urlCoverArt = SMEJEM_SE_A_PLAKAO_BIH;}
        else if (artistRadio == 'ZBOG TEBE BIH TUCAO KAMEN') {var urlCoverArt = ZBOG_TEBE_BIH_TUCAO_KAMEN;}
        else if (artistRadio == 'CRNI PLES') {var urlCoverArt = CRNI_PLES;}
        else if (artistRadio == 'DENIS') {var urlCoverArt = DENIS;}
        else if (artistRadio == 'NADJI ME') {var urlCoverArt = NADJI_ME;}
        else if (artistRadio == 'SAM') {var urlCoverArt = SAM;}
        else if (artistRadio == 'BROD U BOCI') {var urlCoverArt = BROD_U_BOCI;}
        else if (artistRadio == 'CESARICA') {var urlCoverArt = CESARICA;}
        else if (artistRadio == 'DVAPUT SAN UMRA') {var urlCoverArt = DVAPUT_SAN_UMRA;}
        else if (artistRadio == 'KAD MI DODZES TI') {var urlCoverArt = KAD_MI_DODZES_TI;}
        else if (artistRadio == 'NEBO MOJE') {var urlCoverArt = NEBO_MOJE;}
        else if (artistRadio == 'NEDOSTAJES MI TI') {var urlCoverArt = NEDOSTAJES_MI_TI;}
        else if (artistRadio == 'NOCTURNO') {var urlCoverArt = NOCTURNO;}
        else if (artistRadio == 'PISMO MOJA') {var urlCoverArt = PISMO_MOJA;}
        else if (artistRadio == 'PRED TVOJIM VRATIME') {var urlCoverArt = PRED_TVOJIM_VRATIMA;}
        else if (artistRadio == 'STINE') {var urlCoverArt = STINE;}
        else if (artistRadio == 'STO TO BJESE LJUBAV') {var urlCoverArt = STO_TO_BJESE_LJUBAV;}
        else if (artistRadio == 'SVE BI DA ZA NJU') {var urlCoverArt = SVE_BI_DA_ZA_NJU;}
        else if (artistRadio == 'SVIRAJTE NOCAS ZA MOJU DUSU') {var urlCoverArt = SVIRAJTE_NOCAS_ZA_MOJU_DUSU;}
        else if (artistRadio == 'TRAG U BESKRAJU') {var urlCoverArt = TRAG_U_BESKRAJU;}
        else if (artistRadio == 'VJERUJ U LJUBAV') {var urlCoverArt = VJERUJ_U_LJUBAV;}
        else if (artistRadio == 'U LJUBAV VJERE NEMAM FT GIBONI') {var urlCoverArt = U_LJUBAV_VJERE_NEMAM_FT_GIBONNI;}
        else if (artistRadio == 'DZENI') {var urlCoverArt = DZENI;}
        else if (artistRadio == 'E DA SI BAREM NOCAS OVDJE') {var urlCoverArt = E_DA_SI_BAREM_NOCAS_OVDJE;}
        else if (artistRadio == 'E MOJ SASA') {var urlCoverArt = E_MOJ_SASA;}
        else if (artistRadio == 'JA SAM ZA PLES') {var urlCoverArt = JA_SAM_ZA_PLES;}
        else if (artistRadio == 'JESEN JE') {var urlCoverArt = JESEN_JE;}
        else if (artistRadio == 'MILENA') {var urlCoverArt = MILENA;}
        else if (artistRadio == 'CARTE BLANCHE') {var urlCoverArt = CARTE_BLANCHE;}
        else if (artistRadio == 'BEZ TEBE') {var urlCoverArt = BEZ_TEBE;}
        else if (artistRadio == 'DITELINA S CETIRI LISTA') {var urlCoverArt = DITELINA_S_CETRI_LISTA;}
        else if (artistRadio == 'JEDAN OD MNOGIH') {var urlCoverArt = JEDAN_OD_MNOGIH;}
        else if (artistRadio == 'CALIFORNIA') {var urlCoverArt = CALIFORNIA;}
        else if (artistRadio == 'JEANS GENERACIJA') {var urlCoverArt = JEANS_GENERACIJA;}
        else if (artistRadio == 'KAKVA NOC') {var urlCoverArt = KAKVA_NOC;}
        else if (artistRadio == 'DZEMPER ZA VINOGRAD') {var urlCoverArt = DZEMPER_ZA_VINOGRAD;}
        else if (artistRadio == 'KAD BI DOSLA MARIJA') {var urlCoverArt = KAD_BI_DOSLA_MARIJA;}
        else if (artistRadio == 'OD DRUGA DO DRUGA') {var urlCoverArt = OD_DRUGA_DO_DRUGA;}
        else if (artistRadio == 'VINO NOCI FT DEMODE') {var urlCoverArt = VINO_NOCI_FT_DEMODE;}
        else if (artistRadio == 'KOLACICI') {var urlCoverArt = KOLACICI;}
        else if (artistRadio == 'DA MI JE BITI MORSKI PAS') {var urlCoverArt = DA_MI_JE_BITI_MORSKI_PAS;}
        else if (artistRadio == 'AKO JEDNOM CIDIS MARIJU') {var urlCoverArt = AKO_JEDNOM_VIDIS_MARIJU;}
        else if (artistRadio == 'KAD BIH ZNAO DA JE SAMA') {var urlCoverArt = KAD_BIH_ZNAO_DA_JE_SAMA;}
        else if (artistRadio == 'AKO OVO JE KRAJ FT DAVOR DRAGOJEVIC') {var urlCoverArt = AKO_OVO_JE_KRAJ_FT_DAVOR_DRAGOJEVIC;}
        else if (artistRadio == 'APSOLUTNO TVOJ') {var urlCoverArt = APSOLUTNO_TVOJ;}
        else if (artistRadio == 'JA IMAM TE A KO DA NEMAM TE') {var urlCoverArt = JA_IMAM_TE_A_KO_DA_NEMAM_TE;}
        else if (artistRadio == 'PRSTEN I ZLATNI LANAC') {var urlCoverArt = PRSTEN_I_ZLATNI_LANAC;}
        else if (artistRadio == 'STO JE BILO BILO JE') {var urlCoverArt = STO_JE_BILO_BILO_JE;}
        else if (artistRadio == 'ZUTE DUNJE') {var urlCoverArt = ZUTE_DUNJE;}
        else if (artistRadio == 'STO TE NEMA') {var urlCoverArt = STO_TE_NEMA;}
        else if (artistRadio == 'SVE SMO MOGLI MI') {var urlCoverArt = SVE_SMO_MOGLI_MI;}
        else if (artistRadio == 'JA SAM TI JEDINI DRUG') {var urlCoverArt = JA_SAM_TI_JEDINI_DRUG;}
        else if (artistRadio == 'NA OBALI') {var urlCoverArt = NA_OBALI;}
        else if (artistRadio == 'SKITNICA') {var urlCoverArt = SKITNICA;}
        else if (artistRadio == 'DODZI U MALI KAFE') {var urlCoverArt = DODZI_U_MALI_KAFE;}
        else if (artistRadio == 'GOVOR TVOGA TELA') {var urlCoverArt = GOVOR_TVOGA_TELA;}
        else if (artistRadio == 'LJULJAJ ME NEZNO') {var urlCoverArt = LJULJAJ_ME_NEZNO;}
        else if (artistRadio == 'PROBAJ ME') {var urlCoverArt = PROBAJ_ME;}
        else if (artistRadio == 'GDE DA POBEGNEM') {var urlCoverArt = GDE_DA_POBEGNEM;}
        else if (artistRadio == 'MARIJA') {var urlCoverArt = MARIJA;}
        else if (artistRadio == 'MOZDA NEBO ZNA') {var urlCoverArt = MOZDA_NEBO_ZNA;}
        else if (artistRadio == 'S KIM CEKAS DAN') {var urlCoverArt = S_KIM_CEKAS_DAN;}
        else if (artistRadio == 'VINO CRVENO') {var urlCoverArt = VINO_CRVENO;}
        else if (artistRadio == 'IVANA') {var urlCoverArt = IVANA;}
        else if (artistRadio == 'DODJI') {var urlCoverArt = DODJI;}
        else if (artistRadio == 'DOK SI PORED MENE') {var urlCoverArt = DOK_SI_PORED_MENE;}
        else if (artistRadio == 'JESEN_U_MENI') {var urlCoverArt = JESEN_U_MENI;}
        else if (artistRadio == 'KADA ME DOTAKNE') {var urlCoverArt = KADA_ME_DOTAKNE;}
        else if (artistRadio == 'KAO TI') {var urlCoverArt = KAO_TI;}
        else if (artistRadio == 'LJUBAVNA') {var urlCoverArt = LJUBAVNA;}
        else if (artistRadio == 'LUTKA ZA BAL') {var urlCoverArt = LUTKA_ZA_BAL;}
        else if (artistRadio == 'MOJA JE PJESMA LAGANA') {var urlCoverArt = MOJA_JE_PJESMA_LAGANA;}
        else if (artistRadio == 'NEDA') {var urlCoverArt = NEDA;}
        else if (artistRadio == 'PROKLETA NEDELJA') {var urlCoverArt = PROKLETA_NEDELJA;}
        else if (artistRadio == 'SVE JOS MIRISE NA NJU') {var urlCoverArt = SVE_JOS_MIRISE_NA_NJU;}
        else if (artistRadio == 'U LJUBAV VJERUJEM') {var urlCoverArt = U_LJUBAV_VJERUJEM;}
        else if (artistRadio == 'UGASI ME') {var urlCoverArt = UGASI_ME;}
        else if (artistRadio == 'UHVATI RITAM') {var urlCoverArt = UHVATI_RITAM;}
        else if (artistRadio == 'ZASTAVE') {var urlCoverArt = ZASTAVE;}
        else if (artistRadio == 'STRANICE DNEVNIKA') {var urlCoverArt = STRANICE_DNEVNIKA;}
        else if (artistRadio == 'DOLAZIM ZA 5 MINUTA') {var urlCoverArt = DOLAZIM_ZA_5_MINUTA;}
        else if (artistRadio == 'NAJ JACI OSTAJU') {var urlCoverArt = NAJ_JACI_OSTAJU;}
        else if (artistRadio == 'POVEDI ME U NOC') {var urlCoverArt = POVEDI_ME_U_NOC;}
        else if (artistRadio == 'SVEMU DODJE KRAJ') {var urlCoverArt = SVEMU_DODJE_KRAJ;}
        else if (artistRadio == 'TI I JA') {var urlCoverArt = TI_I_JA;}
        else if (artistRadio == 'BI MOGO DA MOGU') {var urlCoverArt = BI_MOGO_DA_MOGU;}
        else if (artistRadio == 'ENA') {var urlCoverArt = ENA;}
        else if (artistRadio == 'MOJA PRVA LJUBAV') {var urlCoverArt = MOJA_PRVA_LJUBAV;}
        else if (artistRadio == 'SAL OD SVILE') {var urlCoverArt = SAL_OD_SVILE;}
        else if (artistRadio == 'SEJN') {var urlCoverArt = SEJN;}
        else if (artistRadio == 'UZALUD PITAS') {var urlCoverArt = UZALUD_PITAS;}
        else if (artistRadio == 'LAGANO UMIREM') {var urlCoverArt = LAGANO_UMIREM;}
        else if (artistRadio == 'CEKALA SAM') {var urlCoverArt = CEKALA_SAM;}
        else if (artistRadio == 'NE LOMI ME') {var urlCoverArt = NE_LOMI_ME;}
        else if (artistRadio == 'RUZMARIN') {var urlCoverArt = RUZMARIN;}

        else if (artistRadio == 'CINI MI SE DA') {var urlCoverArt = CINI_MI_SE_DA;}
        else if (artistRadio == 'KADA SANJAMO') {var urlCoverArt = KADA_SANJAMO;}
        else if (artistRadio == 'NEVERNA SI') {var urlCoverArt = NEVERNA_SI;}
        else if (artistRadio == 'TO JE SUDBINA') {var urlCoverArt = TO_JE_SUDBINA;}
        else if (artistRadio == 'KAO PTICA NA MOM DLANU') {var urlCoverArt = KAO_PTICA_NA_MOM_DLANU;}
        else if (artistRadio == 'TAJNA JE U TEBI SKRIVENA') {var urlCoverArt = TAJNA_JE_U_TEBI_SKRIVENA;}
        else if (artistRadio == 'ZABORAVLJENI') {var urlCoverArt = ZABORAVLJENI;}
        else if (artistRadio == 'AKO SU TO SAMO BILE LAZI') {var urlCoverArt = AKO_SU_TO_SAMO_BILE_LAZI;}
        else if (artistRadio == 'BOLJE BITI PIJAN NEGO STAR') {var urlCoverArt = BOLJE_BITI_PIJAN_NEGO_STAR;}
        else if (artistRadio == 'KAJA') {var urlCoverArt = KAJA;}
        else if (artistRadio == 'LJUBI SE ISTOK I ZAPAD') {var urlCoverArt = LJUBI_SE_ISTOK_I_ZAPAD;}
        else if (artistRadio == 'LOVAC I KOSUTA') {var urlCoverArt = LOVAC_I_KOSUTA;}
        else if (artistRadio == 'GRUDI BALKANSKE') {var urlCoverArt = GRUDI_BALKANSKE;}
        else if (artistRadio == 'NATASA') {var urlCoverArt = NATASA;}
        else if (artistRadio == 'VRATI SE') {var urlCoverArt = VRATI_SE;}
        else if (artistRadio == 'FRIDA') {var urlCoverArt = FRIDA;}
        else if (artistRadio == 'JEDNA MALA PLAVA') {var urlCoverArt = JEDNA_MALA_PLAVA;}
        else if (artistRadio == 'PRINCEZA FT DADO TOPIC') {var urlCoverArt = PRINCEZA_FT_DADO_TOPIC;}
        else if (artistRadio == 'ODLAZIM') {var urlCoverArt = ODLAZIM;}
        else if (artistRadio == 'SAVA TIHO TECE') {var urlCoverArt = SAVA_TIHO_TECE;}
        else if (artistRadio == 'SUADA') {var urlCoverArt = SUADA;}
        else if (artistRadio == 'ZELENE SU BILE OCI TE') {var urlCoverArt = ZELENE_SU_BILE_OCI_TE;}
        else if (artistRadio == 'DECKO AJDE OLADI') {var urlCoverArt = DECKO_AJDE_OLADI;}
        else if (artistRadio == 'SRCE OD MEDA') {var urlCoverArt = SRCE_OD_MEDA;}
        else if (artistRadio == 'TAXI') {var urlCoverArt = TAXI;}
        else if (artistRadio == 'JELENI UMIRU SAMI') {var urlCoverArt = JELENI_UMIRU_SAMI;}
        else if (artistRadio == 'IZ NEKIH STARIH RAZLOGA') {var urlCoverArt = IZ_NEKIH_STARIH_RAZLOGA;}
        else if (artistRadio == 'NE ZOVI MAMA DOKTORA') {var urlCoverArt = NE_ZOVI_MAMA_DOKTORA;}
        else if (artistRadio == 'CRNO BIJELI SVIJET') {var urlCoverArt = CRNO_BIJELI_SVIJET;}
        else if (artistRadio == 'KISE JESENJE') {var urlCoverArt = KISE_JESENJE;}
        else if (artistRadio == 'KORAK OD SNA') {var urlCoverArt = KORAK_OD_SNA;}
        else if (artistRadio == 'MA KOG ME BOGA ZA TEBE PITAJU') {var urlCoverArt = MA_KOG_ME_BOGA_ZA_TEBE_PITAJU;}
        else if (artistRadio == 'MARINA') {var urlCoverArt = MAR_INA;}
        else if (artistRadio == 'MI PLESEMO') {var urlCoverArt = MI_PLESEMO;}
        else if (artistRadio == 'MOJ BIJELI LABUDE') {var urlCoverArt = MOJ_BIJELI_LABUDE;}
        else if (artistRadio == 'S VREMENA NA VRIJEME') {var urlCoverArt = S_VREMENA_NA_VRIJEME;}
        else if (artistRadio == 'UZALUD VAM TRUD SVIRACI') {var urlCoverArt = UZALUD_VAM_TRUD_SVIRACI;}
        else if (artistRadio == 'ZAUSTAVITE ZEMLJU') {var urlCoverArt = ZAUSTAVITE_ZEMLJU;}
        else if (artistRadio == 'AKO TRAZIS NEKOGA') {var urlCoverArt = AKO_TRAZIS_NEKOGA;}
        else if (artistRadio == 'TU NOC KAD SI SE UDAVALA') {var urlCoverArt = TU_NOC_KAD_SI_SE_UDAVALA;}
        else if (artistRadio == 'ZBOG MENE NE PLACI') {var urlCoverArt = ZBOG_MENE_NE_PLACI;}
        else if (artistRadio == 'LOLA') {var urlCoverArt = LOLA;}
        else if (artistRadio == 'TUZNA SU ZELENA POLJA') {var urlCoverArt = TUZNA_SU_ZELENA_POLJA;}
        else if (artistRadio == 'JA VBOLIM SAMO SEBE') {var urlCoverArt = JA_VOLIM_SAMO_SEBE;}
        else if (artistRadio == 'ANDREA') {var urlCoverArt = ANDREA;}
        else if (artistRadio == 'AL KAPONE') {var urlCoverArt = AL_KAPONE;}
        else if (artistRadio == 'AMSTERDAM') {var urlCoverArt = AMSTERDAM;}
        else if (artistRadio == 'AVIONU SLOMICU TI KRILA') {var urlCoverArt = AVIONU_SLOMICU_TI_KRILA;}
        else if (artistRadio == 'DOBRO JUTRO') {var urlCoverArt = DOBRO_JUTRO;}
        else if (artistRadio == 'DVA DINARA DRUZE') {var urlCoverArt = DVA_DINARA_DRUZE;}
        else if (artistRadio == 'GDE SI U OVOM GLUPOM HOTELU') {var urlCoverArt = GDE_SI_U_OVOM_GLUPOM_HOTELU;}
        else if (artistRadio == 'JA JE GLEDAM KAKO SPAVA') {var urlCoverArt = JA_JE_GLEDAM_KAKO_SPAVA;}
        else if (artistRadio == 'JA SAM SE LOZIO NA TEBE') {var urlCoverArt = JA_SAM_SE_LOZIO_NA_TEBE;}
        else if (artistRadio == 'KAD HODAS NE ZASTAJKUJES') {var urlCoverArt = KAD_HODAS_NE_ZASTAJKUJES;}
        else if (artistRadio == 'KAD SAM BIO MLAD') {var urlCoverArt = KAD_SAM_BIO_MLAD;}
        else if (artistRadio == 'KAD PADNE NOC') {var urlCoverArt = KADA_PADNE_NOC;}
        else if (artistRadio == 'KAKO JE LEPO BITI GLUP') {var urlCoverArt = KAKO_JE_LEPO_BITI_GLUP;}
        else if (artistRadio == 'LUTKA SA NASLOVNE STRANE') {var urlCoverArt = LUTKA_SA_NASLOVNE_STRANE;}
        else if (artistRadio == 'NA ZAPADU NISTA NOVO') {var urlCoverArt = NA_ZAPADU_NISTA_NOVO;}
        else if (artistRadio == 'NEMOJ DA IDES MOJOM ULICOM') {var urlCoverArt = NEMOJ_DA_IDES_MOJOM_ULICOM;}
        else if (artistRadio == 'NEMOJ SRECENO NEMOJ DANAS') {var urlCoverArt = NEMOJ_SRECO_NEMOJ_DANAS;}
        else if (artistRadio == 'OSTACU SLOBODAN') {var urlCoverArt = OSTACU_SLOBODAN;}
        else if (artistRadio == 'OSTANI DZUBRE DO KRAJA') {var urlCoverArt = OSTANI_DZUBRE_DO_KRAJA;}
        else if (artistRadio == 'POGLEDAJ DOM SVOJ ANDJELE') {var urlCoverArt = POGLEDAJ_DOM_SVOJ_ANDJELE;}
        else if (artistRadio == 'PRAVILA PRAVILA') {var urlCoverArt = PRAVILA_PRAVILA;}
        else if (artistRadio == 'VOLIM VOLIM ZENE') {var urlCoverArt = VOLIM_VOLIM_ZENE;}
        else if (artistRadio == 'COKOLADA') {var urlCoverArt = COKOLADA;}
        else if (artistRadio == 'DEVOJKO MALA') {var urlCoverArt = DEVOJKO_MALA;}
        else if (artistRadio == 'MALENA') {var urlCoverArt = MALENA;}
        else if (artistRadio == 'ONA TO ZNA') {var urlCoverArt = ONA_TO_ZNA;}
        else if (artistRadio == 'BACILA JE SVE NIZ RIJEKU') {var urlCoverArt = BACILA_JE_SVE_NIZ_RIJEKU;}
        else if (artistRadio == 'BALADA') {var urlCoverArt = BALADA;}
        else if (artistRadio == 'DA SAM JA NETKO') {var urlCoverArt = DA_SAM_JA_NETKO;}
        else if (artistRadio == 'PREDAJ SE SRCE') {var urlCoverArt = PREDAJ_SE_SRCE}
        else if (artistRadio == 'SANJAM') {var urlCoverArt = SANJAM;}
        else if (artistRadio == 'SVE OVE GODINE') {var urlCoverArt = SVE_OVE_GODINE;}
        else if (artistRadio == 'TI SI MI BILA NAJ NAJ') {var urlCoverArt = TI_SI_MI_BILA_NAJ_NAJ;}
        else if (artistRadio == 'DANAS SAM LUDA') {var urlCoverArt = DANAS_SAM_LUDA;}
        else if (artistRadio == 'GDJE DUNAV LJUBIO NEBO') {var urlCoverArt = GDJE_DUNAV_LJUBI_NEBO;}
        else if (artistRadio == 'MAGLA') {var urlCoverArt = MAGLA;}
        else if (artistRadio == 'NOCNA PTICA') {var urlCoverArt = NOCNA_PTICA;}
        else if (artistRadio == 'O JEDNOJ MLADOSTI') {var urlCoverArt = O_JEDNOJ_MLADOSTI;}
        else if (artistRadio == 'RUSILA SAM MOSTOVE FT DINO DVORNIK') {var urlCoverArt = RUSILA_SAM_MOSTOVE_FT_DINO_DVORNIK;}
        else if (artistRadio == 'CAO AMORE FT VLADO KALEMBAR') {var urlCoverArt = CAO_AMORE_FT_VLADO_KALEMBAR;}
        else if (artistRadio == 'POVEDI ME') {var urlCoverArt = POVEDI_ME;}
        else if (artistRadio == 'ANA') {var urlCoverArt = ANA;}
        else if (artistRadio == 'JA NISAM KOCKAR') {var urlCoverArt = JA_NISAM_KOCKAR;}
        else if (artistRadio == 'ZAKUNI SE LJUAVI') {var urlCoverArt = ZAKUNI_SE_LJUBAVI;}
        else if (artistRadio == 'CRNA DANA') {var urlCoverArt = CRNA_DAMA;}
        else if (artistRadio == 'DAIRE') {var urlCoverArt = DAIRE;}
        else if (artistRadio == 'KOKETA') {var urlCoverArt = KOKETA;}
        else if (artistRadio == 'VOLIO SAM TANJU') {var urlCoverArt = VOLIO_SAM_TANJU;}
        else if (artistRadio == 'S VREMENA NA VREME') {var urlCoverArt = S_VREMENA_NA_VREME;}
        else if (artistRadio == 'KOFER LJUBAVI') {var urlCoverArt = KOFER_LJUBAVI;}
        else if (artistRadio == 'RODJENI') {var urlCoverArt = RODJENI;}
        else if (artistRadio == 'DALEKO') {var urlCoverArt = DALEKO;}
        else if (artistRadio == 'DUSO MOJA') {var urlCoverArt = DUSO_MOJA;}
        else if (artistRadio == 'JEDNE NOCI U DECEMBRU') {var urlCoverArt = JEDNE_NOCI_U_DECEMBRU;}
        else if (artistRadio == 'NAPISI JEDNU LJBAVNU') {var urlCoverArt = NAPISI_JEDNU_LJUBAVNU;}
        else if (artistRadio == 'NIJE HTELA') {var urlCoverArt = NIJE_HTJELA;}
        else if (artistRadio == 'OVAKO NE MOGU DALJE') {var urlCoverArt = OVAKO_NE_MOGU_DALJE;}
        else if (artistRadio == 'VRATIO SAM SE ZIVOTE') {var urlCoverArt = VRATIO_SAM_SE_ZIVOTE;}
        else if (artistRadio == 'BOLJE DA SAM DRUGE LJUBIO') {var urlCoverArt = BOLJE_DA_SAM_DRUGE_LJUBIO;}
        else if (artistRadio == 'COVEK OD MEDA') {var urlCoverArt = COVEK_OD_MEDA;}
        else if (artistRadio == 'HAJDE DA SE VOLIMO') {var urlCoverArt = HAJDE_DA_SE_VOLIMO;}
        else if (artistRadio == 'NA RASKRSCU') {var urlCoverArt = NA_RASKRSCU;}
        else if (artistRadio == 'RATNE IGRE') {var urlCoverArt = RATNE_IGRE;}
        else if (artistRadio == 'PLAVUSA') {var urlCoverArt = PLAVUSA;}
        else if (artistRadio == 'ZBOG JEDNE DIVNE CRNE ZENE') {var urlCoverArt = ZBOG_JEDNE_DIVNE_CRNE_ZENE;}
        else if (artistRadio == 'POKRENI ME') {var urlCoverArt = POKRENI_ME;}
        else if (artistRadio == 'SIZIKA') {var urlCoverArt = SIZIKA;}
        else if (artistRadio == 'AJDE AJDE JASMINA') {var urlCoverArt = AJDE_AJDE_JASMINA;}
        else if (artistRadio == 'APRIL U BEOGRADU') {var urlCoverArt = APRIL_U_BEOGRADU;}
        else if (artistRadio == 'CINI MI SE GRMI') {var urlCoverArt = CINI_MI_SE_GRMI;}
        else if (artistRadio == 'DA TI KAZEM STA MI JE') {var urlCoverArt = DA_TI_KAZEM_STA_MI_JE;}
        else if (artistRadio == 'GORI VATRA') {var urlCoverArt = GORI_VATRA;}
        else if (artistRadio == 'KAD BI MOJA BILA') {var urlCoverArt = KAD_BI_MOJA_BILA;}
        else if (artistRadio == 'MADJARICA') {var urlCoverArt = MADJARICA;}
        else if (artistRadio == 'MALO POJACAJ RADIO') {var urlCoverArt = MALO_POJACAJ_RADIO;}
        else if (artistRadio == 'PISACU JOJ PISMA DUGA') {var urlCoverArt = PISACU_JOJ_PISMA_DUGA;}
        else if (artistRadio == 'RIJEKA SUZA I NA NJOJ LADJA') {var urlCoverArt = RIJEKA_SUZA_I_NA_NJOJ_LADJA;}
        else if (artistRadio == 'RUSKA') {var urlCoverArt = RUSKA;}
        else if (artistRadio == 'SINOC NISI BILA TU') {var urlCoverArt = SINOC_NISI_BILA_TU;}
        else if (artistRadio == 'STA MI RADIS') {var urlCoverArt = STA_MI_RADIS;}
        else if (artistRadio == 'ZIVIS U OBLACIMA') {var urlCoverArt = ZIVIS_U_OBLACIMA;}
        else if (artistRadio == 'DA LI ZNAS DA TE VOLIM') {var urlCoverArt = DA_LI_ZNAS_DA_TE_VOLIM;}
        else if (artistRadio == 'MAKEDONIJA') {var urlCoverArt = MAKEDONIJA;}
        else if (artistRadio == 'ZDENKA KOVACICEK') {var urlCoverArt = ZDENKA_KOVACICEK;}
        else if (artistRadio == 'SEDAMNEST TI JE GODINA FT HARI MATA HARI') {var urlCoverArt = SEDAMNEST_TI_JE_GODINA_FT_HARI_MATA_HARI;}
        else if (artistRadio == 'DVIJE ZVJEZDICE') {var urlCoverArt = DVIJE_ZVJEZDICE;}
        else if (artistRadio == 'MILION GODINA') {var urlCoverArt = MILION_GODINA;}
        else if (artistRadio == 'MOJ MALI JE OPASAN') {var urlCoverArt = MOJ_MALI_JE_OPASAN;}
        else if (artistRadio == 'NEMA VISE LJUBAVI') {var urlCoverArt = NEMA_VISE_LJUBAVI;}
        else if (artistRadio == 'MOJA POSLEDNJA I PRVA LJUBAVI') {var urlCoverArt = MOJA_POSLEDNJA_I_PRVA_LJUBAVI;}
        else if (artistRadio == 'PRIJATELJI STARI GDJE STE') {var urlCoverArt = PRIJATELJI_STARI_GDJE_STE;}
        else if (artistRadio == 'DESET GODINA') {var urlCoverArt = DESET_GODINA;}
        else if (artistRadio == 'SRCE SRNE KOJA DRHTI') {var urlCoverArt = SRCE_SRNE_KOJA_DRHTI;}
        else if (artistRadio == 'KRILA LEPTIRA') {var urlCoverArt = KRILA_LEPTIRA;}
        else if (artistRadio == 'BILO MI JE LIJEPO S TOBOM') {var urlCoverArt = BILO_MI_JE_LIJEPO_S_TOBOM;}
        else if (artistRadio == 'NE MOZE TO TAKO') {var urlCoverArt = NE_MOZE_TO_TAKO;}
        else if (artistRadio == 'NE DAJ MI DA GOVORIM U SNU') {var urlCoverArt = NE_DAJ_MI_DA_GOVORIM_U_SNU;}
        else if (artistRadio == 'OKA TVOJA DVA') {var urlCoverArt = OKA_TVOJA_DVA;}
        else if (artistRadio == 'DETEKTIVSKA PRICA') {var urlCoverArt = DETEKTIVSKA_PRICA;}
        else if (artistRadio == 'IZNENADI ME') {var urlCoverArt = IZNENADI_ME;}
        else if (artistRadio == 'OD ZLATA JABUKA') {var urlCoverArt = OD_ZLATA_JABUKA;}
        else if (artistRadio == 'TOTALNO DRUKCIJI OD DRUGIH') {var urlCoverArt = TOTALNO_DRUKCIJI_OD_DRUGIH;}
        else if (artistRadio == 'VLAK') {var urlCoverArt = VLAK;}
        else if (artistRadio == 'DUNAVOM JOS SIBAJU VETROVI') {var urlCoverArt = DUNAVOM_JOS_SIBAJU_VETROVI;}
        else if (artistRadio == 'KOME SA RADUJES') {var urlCoverArt = KOME_SE_RADUJES;}
        else if (artistRadio == 'CRNI LEPTIR') {var urlCoverArt = CRNI_LEPTIR;}
        else if (artistRadio == 'MORNAR') {var urlCoverArt = MORNAR;}
        else if (artistRadio == 'ZA MILION GODINA') {var urlCoverArt = ZA_MILION_GODINA;}
        else if (artistRadio == 'BALADA O PISONJI I ZUGI') {var urlCoverArt = BALADA_O_PISONJI_I_ZUGI;}
        else if (artistRadio == 'DJEVOJCICE KOJIMA MIRISE KOZA') {var urlCoverArt = DJEVOJCICE_KOJIMA_MIRISE_KOZA;}
        else if (artistRadio == 'HADZIJA ILI BOS') {var urlCoverArt = HADZIJA_ILI_BOS;}
        else if (artistRadio == 'JUGO 45') {var urlCoverArt = JUGO_45;}
        else if (artistRadio == 'MOZES IMAT MOJE TIJELO') {var urlCoverArt = MOZES_IMAT_MOJE_TIJELO;}
        else if (artistRadio == 'ZENICA BLUES') {var urlCoverArt = ZENICA_BLUES;}
        else if (artistRadio == 'DODIRNI MI KOLENA') {var urlCoverArt = DODIRNI_MI_KOLENA;}
        else if (artistRadio == 'JABUKE I VINO') {var urlCoverArt = JABUKE_I_VINO;}
        else if (artistRadio == 'MAJSTOR ZA POLJUPCE') {var urlCoverArt = MAJSTOR_ZA_POLJUPCE;}
        else if (artistRadio == 'MLADICU MOJ') {var urlCoverArt = MLADICU_MOJ;}
        else if (artistRadio == 'NAJDE DA LUDUJEMO') {var urlCoverArt = HAJDE_DA_LUDUJEMO;}
        else if (artistRadio == 'TI NEMAS PRAVA NA MENE') {var urlCoverArt = TI_NEMAS_PRAVA_NA_MENE;}
        else if (artistRadio == 'NE BOJIM SE DRUGOVA TVOGA FRAJERA') {var urlCoverArt = NE_BOJIM_SE_DRUGOVA_TVOGA_FRAJERA;}
        else if (artistRadio == 'STVARI LAGANE') {var urlCoverArt = STVARI_LAGANE;}
        else if (artistRadio == 'TI ME IZLUDUJES') {var urlCoverArt = TI_ME_IZLUDUJES;}
        else if (artistRadio == 'A TI SI MANGUP') {var urlCoverArt = A_TI_SI_MANGUP;}
        else if (artistRadio == 'IMAM JEDAN SVIJET') {var urlCoverArt = IMA_JEDAN_SVIJET;}
        else if (artistRadio == 'SVE JE NEOVICNO AKO TE VOLIM') {var urlCoverArt = SVE_JE_NEOBICNO_AKO_TE_VOLIM;}
        else if (artistRadio == 'STIPU GATIBO') {var urlCoverArt = STIPU_GATIBO;}
        else if (artistRadio == 'STO NE ZNAM GDE SI SAD') {var urlCoverArt = STO_NE_ZNAM_GDE_SI_SAD;}
        else if (artistRadio == 'VOJAN POSTA') {var urlCoverArt = VOJAN_POSTA;}
        else if (artistRadio == 'ZNAM I OSECAM') {var urlCoverArt = ZNAM_I_OSECAM;}
        else if (artistRadio == 'OZENICES SE TI') {var urlCoverArt = OZENICES_SE_TI;}
        else if (artistRadio == 'RUKUJU SE RUKUJU') {var urlCoverArt = RUKUJU_SE_RUKUJU;}
        else if (artistRadio == 'ZANA VEJTE SNEGOVI') {var urlCoverArt = ZANA_VEJTE_SNEGOVI;}
        else if (artistRadio == 'RAT I MIR') {var urlCoverArt = RAT_I_MIR;}
        else if (artistRadio == 'ARIJA') {var urlCoverArt = ARIJA;}
        else if (artistRadio == 'BARAKUDA') {var urlCoverArt = BARAKUDA;}
        else if (artistRadio == 'DAJ NE PITAJ') {var urlCoverArt = DAJ_NE_PITAJ;}
        else if (artistRadio == 'SAMO TERAJ TI PO SVOME') {var urlCoverArt = SAMO_TERAJ_TI_PO_SVOME;}
        else if (artistRadio == 'VINO NA USNAMA') {var urlCoverArt = VINO_NA_USNAMA;}
        else if (artistRadio == 'TROJE') {var urlCoverArt = TROJE;}
        else if (artistRadio == 'NIKAD TE NIKO NECE VOLET KO JA') {var urlCoverArt = NIKAD_TE_NIKO_NECE_VOLJET_KO_JA;}
        else if (artistRadio == 'NEKO TE IMA') {var urlCoverArt = NEKO_TE_IMA;}
        else if (artistRadio == 'ZLATNA RIBICA') {var urlCoverArt = ZLATNA_RIBICA;}
        else if (artistRadio == 'PONEKAD NOCU DOK SPAVA GRAD') {var urlCoverArt = PONEKAD_NOCU_DOK_SPAVA_GRAD;}
        else if (artistRadio == 'IDU PTICE SELICE') {var urlCoverArt = IDU_PTICE_SELICE;}
        else if (artistRadio == 'NE MOGU NE MOGU') {var urlCoverArt = NE_MOGU_NE_MOGU;}
        else if (artistRadio == 'PILE MOJE') {var urlCoverArt = PILE_MOJE;}
        else if (artistRadio == 'SAMO SKLOPI OKICE') {var urlCoverArt = SAMO_SKLOPI_OKICE;}
        else if (artistRadio == 'VOLM TE JOS') {var urlCoverArt = VOLIM_TE_JOS;}
        else if (artistRadio == 'IZGLEDA DA MI SMO SAMI') {var urlCoverArt = IZGLEDA_DA_MI_SMO_SAMI;}
        else if (artistRadio == 'KOLIKO IMAS GODINA') {var urlCoverArt = KOLIKO_IMAS_GODINA;}
        else if (artistRadio == 'NOVE GODINE') {var urlCoverArt = NOVE_GODINE;}
        else if (artistRadio == 'O_JE') {var urlCoverArt = O_JE;}
        else if (artistRadio == 'SIDJI DO REKE') {var urlCoverArt = SIDJI_DO_REKE;}
        else if (artistRadio == 'JUZNJACI') {var urlCoverArt = JUZNJACI;}
        else if (artistRadio == 'OKANO') {var urlCoverArt = OKANO;}
        else if (artistRadio == 'PRAVA STVAR') {var urlCoverArt = PRAVA_STVAR;}
        else if (artistRadio == 'TI MOZES SVE') {var urlCoverArt = TI_MOZES_SVE;}
        else if (artistRadio == 'TI SI MI U KRVI') {var urlCoverArt = TI_SI_MI_U_KRVI;}
        else if (artistRadio == 'AJDE AJDE IDI') {var urlCoverArt = AJDE_AJDE_IDI;}
        else if (artistRadio == 'HOTEL BALKAN') {var urlCoverArt = HOTEL_BALKAN;}
        else if (artistRadio == 'KRASIVA') {var urlCoverArt = KRASIVA;}
        else if (artistRadio == 'NOC MI TE DUGUJE') {var urlCoverArt = NOC_MI_TE_DUGUJE;}
        else if (artistRadio == 'OJ DEVOJKO SELEN VELEN') {var urlCoverArt = OJ_DEVOJKO_SELEN_VELEN;}
        else if (artistRadio == 'JEDINA') {var urlCoverArt = JEDINA;}
        else if (artistRadio == 'PJEVAM DANJU PJEVAM NOCU') {var urlCoverArt = PJEVAM_DANJU_PJEVAM_NOCU;}
        else if (artistRadio == 'ZVAO SAM JE EMILI') {var urlCoverArt = ZVAO_SAM_JE_EMILI;}
        else if (artistRadio == 'CAJE SUKARIJE') {var urlCoverArt = CAJE_SUKARIJE;}
        else if (artistRadio == 'CIJA JE ONA ZVIJEZDA') {var urlCoverArt = CIJA_JE_ONO_ZVIJEZDA;}
        else if (artistRadio == 'E DRAGA DRAGA') {var urlCoverArt = E_DRAGA_DRAGA;}
        else if (artistRadio == 'GLAVO LUDA') {var urlCoverArt = GLAVO_LUDA;}
        else if (artistRadio == 'JEDINA ZIMA SA KRISTINOM') {var urlCoverArt = JEDNA_ZIMA_SA_KRISTINOM;}
        else if (artistRadio == 'MASLINASTO ZELENA') {var urlCoverArt = MASLINASTO_ZELENA;}
        else if (artistRadio == 'MASTILO I VODA') {var urlCoverArt = MASTILO_I_VODA;}
        else if (artistRadio == 'NEGDJE NE DNU SRCA') {var urlCoverArt = NEGDJE_NA_DNU_SRCA;}
        else if (artistRadio == 'PRODUZI DALJE') {var urlCoverArt = PRODUZI_DALJE;}
        else if (artistRadio == 'STANICA PODLUGOVI') {var urlCoverArt = STANICA_PODLUGOVI;}
        else if (artistRadio == 'ZAGRLI ME') {var urlCoverArt = ZAGRLI_ME;}
        else if (artistRadio == 'ZBOG TEBE') {var urlCoverArt = ZBOG_TEBE;}
        else if (artistRadio == 'DA JE SRECE BILO') {var urlCoverArt = DA_JE_SRECE_BILO;}
        else if (artistRadio == 'KUCKA NEVERNA') {var urlCoverArt = KUCKA_NEVERNA;}
        else if (artistRadio == 'MENE TJERA NEKI VRAG') {var urlCoverArt = MENE_TJERA_NEKI_VRAG;}
        else if (artistRadio == 'OPROSTI MI STO TE VOLIM') {var urlCoverArt = OPROSTI_MI_STO_TE_VOLIM;}
        else if (artistRadio == 'TIJANA') {var urlCoverArt = TIJANA;}
        else if (artistRadio == 'SINOC SAM POLA KAFANE POPIO') {var urlCoverArt = SINOC_SAM_POLA_KAFANE_POPIO;}
        else if (artistRadio == 'OVE NOCI JEDNA ZENA') {var urlCoverArt = OVE_NOCI_JEDNA_ZENA;}
        else if (artistRadio == 'GRADSKE CURE') {var urlCoverArt = GRADSKE_CURE;}
        else if (artistRadio == 'KAKVA NOC') {var urlCoverArt = KAKVA_NOC;}
        else if (artistRadio == 'DOBRE DEVOJKE') {var urlCoverArt = DOBRE_DEVOJKE;}
        else if (artistRadio == 'BALKANSKA ULICA') {var urlCoverArt = BALKANSKA_ULICA;}
        else if (artistRadio == 'KAKO SAM TE VOLJELA') {var urlCoverArt = KAKO_SAM_TE_VOLJELA;}
        else if (artistRadio == 'STO SAM JA STO SI TI') {var urlCoverArt = STO_SAM_JA_STO_SI_TI;}
        else if (artistRadio == 'RANO') {var urlCoverArt = RANO;}
        else if (artistRadio == 'ROCK ME') {var urlCoverArt = ROCK_ME;}
        else if (artistRadio == 'KUCA PORED MORA') {var urlCoverArt = KUCA_PORED_MORA;}
        else if (artistRadio == 'PJEVALI SMO PJESME STARE') {var urlCoverArt = PJEVALI_SMO_PJESME_STARE;}
        else if (artistRadio == 'POZOVI ME') {var urlCoverArt = POZOVI_ME;}
        else if (artistRadio == 'IBRO DIRKA') {var urlCoverArt = IBRO_DIRKA;}
        else if (artistRadio == 'MENI MAMA NE DA') {var urlCoverArt = MENI_MAMA_NE_DA;}
        else if (artistRadio == 'RADOSTAN DAN') {var urlCoverArt = RADOSTAN_DAN;}
        else if (artistRadio == 'MOZDA MOZDA') {var urlCoverArt = MOZDA_MOZDA;}
        else if (artistRadio == 'LJUBAV NIJE ZA NAS') {var urlCoverArt = LJUBAV_NIJE_ZA_NAS;}
        else if (artistRadio == 'JEDAN COVEK JEDNA ZENA') {var urlCoverArt = JEDAN_COVEK_JEDNA_ZENA;}
        else if (artistRadio == 'GALEBOVI') {var urlCoverArt = GALEBOVI;}
        else if (artistRadio == 'JELENA') {var urlCoverArt = JELENA;}
        else if (artistRadio == 'GLASNO GLASNIJE') {var urlCoverArt = GLASNO_GLASNIJE;}
        else if (artistRadio == 'OD SPLITA DO BEOGRADA FT DINO DVORNIK') {var urlCoverArt = OD_SPLITA_DO_BEOGRADA_FT_DINO_DVORNIK;}
        else if (artistRadio == 'PISMO') {var urlCoverArt = PISMO;}
        else if (artistRadio == 'DALMATINKA') {var urlCoverArt = DALMATINKA;}
        else if (artistRadio == 'KAZI MI DA SI JOS UVEK SAMA') {var urlCoverArt = KAZU_MI_DA_SI_JOS_UVEK_SAMA;}
        else if (artistRadio == 'PARISKI LOKAL') {var urlCoverArt = PARISKI_LOKAL;}
        else if (artistRadio == 'AJSA') {var urlCoverArt = AJSA;}
        else if (artistRadio == 'ELIZABET') {var urlCoverArt = ELIZABET;}
        else if (artistRadio == 'CUVAJ SE') {var urlCoverArt = CUVAJ_SE;}
        else if (artistRadio == 'JUBI SAN VASU KCER') {var urlCoverArt = JUBI_SAN_VASU_KCER;}
        else if (artistRadio == 'JEDNU MLADOST IMAM') {var urlCoverArt = JEDNU_MLADOST_IMAM;}
        else if (artistRadio == 'HARMONIKA') {var urlCoverArt = HARMONIKA;}
        else if (artistRadio == 'JUGOSLOVENKA') {var urlCoverArt = JUGOSLOVENKA;}
        else if (artistRadio == 'RUSKA COKOLADA') {var urlCoverArt = RUSKA_COKOLADA;}
        else if (artistRadio == 'JEDINO MOJE') {var urlCoverArt = JEDINO_MOJE;}
        else if (artistRadio == 'DOK GITARA SVIRA') {var urlCoverArt = DOK_GITARA_SVIRA;}
        else if (artistRadio == 'AERODROM'){var urlCoverArt = AERODROM;}
        else if (artistRadio == 'ALEKSANDAR MEZEK') {var urlCoverArt = ALEKSANDAR_MEZEK;}
        else if (artistRadio == 'SLADJANA MILOSEVIC') {var urlCoverArt = SLADJANA_MILOSEVIC;}
        else if (artistRadio == 'ALEN SLAVICA') {var urlCoverArt = ALEN_SLAVICA;}
        else if (artistRadio == 'ALISA') {var urlCoverArt = ALISA;}
        else if (artistRadio == 'ALKA VUJICA') {var urlCoverArt = ALKA_VUJICA;}
        else if (artistRadio == 'AMBASADORI') {var urlCoverArt = AMBASADORI;}
        else if (artistRadio == 'ANIMATORI') {var urlCoverArt = ANIMATORI;}
        else if (artistRadio == 'ARSEN DEDIC') {var urlCoverArt = ARSEN_DEDIC;}
        else if (artistRadio == 'ATOMSKO SKLONISTE') {var urlCoverArt = ATOMSKO_SKLONISTE;}
        else if (artistRadio == 'AZRA') {var urlCoverArt = AZRA;}
        else if (artistRadio == 'BABE') {var urlCoverArt = BABE;}
        else if (artistRadio == 'BAJAGA') {var urlCoverArt = BAJAGA;}
        else if (artistRadio == 'BEBI DOL') {var urlCoverArt = BEBI_DOL;}
        else if (artistRadio == 'BJELO DUGME') {var urlCoverArt = BJELO_DUGME;}
        else if (artistRadio == 'BISERA VELETANLIC') {var urlCoverArt = BISERA_VELETANLIC;}
        else if (artistRadio == 'BOBA STEFANOVIC') {var urlCoverArt = BOBA_STEFANOVIC;}
        else if (artistRadio == 'BOLERO') {var urlCoverArt = BOLERO;}
        else if (artistRadio == 'BOBAJ STAMPA') {var urlCoverArt = BOBAJ_STAMPA;}
        else if (artistRadio == 'BORIS NOVKOVIC') {var urlCoverArt = BORIS_NOVKOVIC;}
        else if (artistRadio == 'CRVENA JABUKA') {var urlCoverArt = CRVENA_JABUKA;}
        else if (artistRadio == 'DADO TOPIC') {var urlCoverArt = DADO_TOPIC;}
        else if (artistRadio == 'DALEKA OBALA') {var urlCoverArt = DALEKA_OBALA;}
        else if (artistRadio == 'DANIJEL POPOVIC') {var urlCoverArt = DANIJEL_POPOVIC;}
        else if (artistRadio == 'DANIJELA MARTINOVIC') {var urlCoverArt = DANIJELA_MARTINOVIC;}
        else if (artistRadio == 'DARKO DOMIJAN') {var urlCoverArt = DARKO_DOMIJAN;}
        else if (artistRadio == 'DEJAN CUKIC') {var urlCoverArt = DEJAN_CUKIC;}
        else if (artistRadio == 'DENIS DENIS') {var urlCoverArt = DENIS_DENIS;}
        else if (artistRadio == 'DINO DVORNIK') {var urlCoverArt = DINO_DVORNIK;}
        else if (artistRadio == 'DINO MERLIN') {var urlCoverArt = DINO_MERLIN;}
        else if (artistRadio == 'DIVLJE JAGODE') {var urlCoverArt = DIVLJE_JAGODE;}
        else if (artistRadio == 'DIVLJI ANDJELI') {var urlCoverArt = DIVLJI_ANDJELI;}
        else if (artistRadio == 'DJAVOLI') {var urlCoverArt = DJAVOLI;}
        else if (artistRadio == 'DJORDJE BALASEVIC') {var urlCoverArt = DJORDJE_BALASEVIC;}
        else if (artistRadio == 'DORIAN GRAY') {var urlCoverArt = DORIAN_GRAY;}
        else if (artistRadio == 'DORIS DRAGOVIC') {var urlCoverArt = DORIS_DRAGOVIC;}
        else if (artistRadio == 'DRAGAN STOJNIC') {var urlCoverArt = DRAGAN_STOJNIC;}
        else if (artistRadio == 'DRAZEN ZECIC') {var urlCoverArt = DRAZEN_ZECIC;}
        else if (artistRadio == 'DRUGI NACIN') {var urlCoverArt = DRUGI_NACIN;}
        else if (artistRadio == 'EKATERINA VELIKA') {var urlCoverArt = EKATERINA_VELIKA;}
        else if (artistRadio == 'ELEKTRICNI ORGAZAM') {var urlCoverArt = ELEKTRICNI_ORGAZAM;}
        else if (artistRadio == 'ELVIRA RAHIC') {var urlCoverArt = ELVIRA_RAHIC;}
        else if (artistRadio == 'FAMILIJA') {var urlCoverArt = FAMILIJA;}
        else if (artistRadio == 'FILM') {var urlCoverArt = FILM;}
        else if (artistRadio == 'FIT') {var urlCoverArt = FIT;}
        else if (artistRadio == 'FRANO LASIC') {var urlCoverArt = FRANO_LASIC;}
        else if (artistRadio == 'FRKA') {var urlCoverArt = FRKA;}
        else if (artistRadio == 'GABI NOVAK') {var urlCoverArt = GABI_NOVAK;}
        else if (artistRadio == 'GALIJA') {var urlCoverArt = GALIJA;}
        else if (artistRadio == 'GENERACIJA 5') {var urlCoverArt = GENERACIJA_5;}
        else if (artistRadio == 'GIBONNI') {var urlCoverArt = GIBONNI;}
        else if (artistRadio == 'GRUPA 220') {var urlCoverArt = GRUPA_220;}
        else if (artistRadio == 'HARI MATA HARI') {var urlCoverArt = HARI_MATA_HARI;}
        else if (artistRadio == 'HAUSTOR') {var urlCoverArt = HAUSTOR;}
        else if (artistRadio == 'IBRICA JUSIC') {var urlCoverArt = IBRICA_JUSIC;}
        else if (artistRadio == 'IDOLI') {var urlCoverArt = IDOLI;}
        else if (artistRadio == 'INDEXI') {var urlCoverArt = INDEXI;}
        else if (artistRadio == 'ITD BAND') {var urlCoverArt = ITD_BAND;}
        else if (artistRadio == 'IZOLDA') {var urlCoverArt = IZOLDA;}
        else if (artistRadio == 'JADRANKA STOJANKOVIC') {var urlCoverArt = JADRANKA_STOJAKOVIC;}
        else if (artistRadio == 'JAKARTA') {var urlCoverArt = JAKARTA;}
        else if (artistRadio == 'JASNA ZLOKIC') {var urlCoverArt = JASNA_ZLOKIC;}
        else if (artistRadio == 'JOSIPA LISAC') {var urlCoverArt = JOSIPA_LISAC;}
        else if (artistRadio == 'KALIOPI') {var urlCoverArt = KALIOPI;}
        else if (artistRadio == 'KEMAL MONTENO') {var urlCoverArt = KEMAL_MONTENO;}
        else if (artistRadio == 'KERBER') {var urlCoverArt = KERBER;}
        else if (artistRadio == 'KICO SLABINAC') {var urlCoverArt = KICO_SLABINAC;}
        else if (artistRadio == 'KSENIJA ERKER') {var urlCoverArt = KSENIJA_ERKER;}
        else if (artistRadio == 'LAKI PINGVINI') {var urlCoverArt = LAKI_PINGVINI;}
        else if (artistRadio == 'LEB I SOL') {var urlCoverArt = LEB_I_SOL;}
        else if (artistRadio == 'LEO MARTIN') {var urlCoverArt = LEO_MARTIN;}
        else if (artistRadio == 'LETECI ODRED') {var urlCoverArt = LETECI_ODRED;}
        else if (artistRadio == 'MAGAZIN') {var urlCoverArt = MAGAZIN;}
        else if (artistRadio == 'MARINA PERAZIC') {var urlCoverArt = MARINA_PERAZIC;}
        else if (artistRadio == 'MAGAZIN') {var urlCoverArt = MAGAZIN;}
        else if (artistRadio == 'MASSIMO SLAVIC') {var urlCoverArt = MASSIMO_SAVIC;}
        else if (artistRadio == 'MERI CETINIC') {var urlCoverArt = MERI_CETINIC;}
        else if (artistRadio == 'MERLIN') {var urlCoverArt = MERLIN;}
        else if (artistRadio == 'METAK') {var urlCoverArt = METAK;}
        else if (artistRadio == 'MIKI JEVREMOVIC') {var urlCoverArt = MIKI_JEVREMOVIC;}
        else if (artistRadio == 'MILADIN SOBIC') {var urlCoverArt = MILADIN_SOBIC;}
        else if (artistRadio == 'MINEA') {var urlCoverArt = MINEA;}
        else if (artistRadio == 'MIRZINO JATO') {var urlCoverArt = MIRZINO_JATO;}
        else if (artistRadio == 'MISO KOVAC') {var urlCoverArt = MISO_KOVAC;}
        else if (artistRadio == 'NEDA UKRADEN') {var urlCoverArt = NEDA_UKRADEN;}
        else if (artistRadio == 'NEKI TO VOLE VRUCE') {var urlCoverArt = NEKI_TO_VOLE_VRUCE;}
        else if (artistRadio == 'NENO BELAN') {var urlCoverArt = NENO_BELAN;}
        else if (artistRadio == 'NOVI FOSILI') {var urlCoverArt = NOVI_FOSILI;}
        else if (artistRadio == 'OKTOBAR 1864') {var urlCoverArt = OKTOBAR_1864;}
        else if (artistRadio == 'OLIVER DRAGOJEVIC') {var urlCoverArt = OLIVER_DRAGOJEVIC;}
        else if (artistRadio == 'OLIVER MANDIC') {var urlCoverArt = OLIVER_MANDIC;}
        else if (artistRadio == 'OLIVERA KATARINA') {var urlCoverArt = OLIVERA_KATARINA;}
        else if (artistRadio == 'OSMI PUTNIK') {var urlCoverArt = OSMI_PUTNIK;}
        else if (artistRadio == 'OSVAJACI') {var urlCoverArt = OSVAJACI;}
        else if (artistRadio == 'PARNI VALJAK') {var urlCoverArt = PARNI_VALJAK;}
        else if (artistRadio == 'PEDJA D BOY') {var urlCoverArt = PEDJA_D_BOY;}
        else if (artistRadio == 'PILOTI') {var urlCoverArt = PILOTI;}
        else if (artistRadio == 'PLAVI ORKESTAR') {var urlCoverArt = PLAVI_ORKESTAR;}
        else if (artistRadio == 'POSLEDNJA IGRA LEPTIRA') {var urlCoverArt = POSLEDNJA_IGRA_LEPTIRA;}
        else if (artistRadio == 'PRLJAVO KAZALISTE') {var urlCoverArt = PRLJAVO_KAZALISTE;}
        else if (artistRadio == 'PRO ARTE') {var urlCoverArt = PRO_ARTE;}
        else if (artistRadio == 'PSIHOMODO POP') {var urlCoverArt = PSIHOMODO_POP;}
        else if (artistRadio == 'REGATA') {var urlCoverArt = REGATA;}
        else if (artistRadio == 'REGINA') {var urlCoverArt = REGINA;}
        else if (artistRadio == 'RIBLJA CORBA') {var urlCoverArt = RIBLJA_CORBA;}
        else if (artistRadio == 'RIVA') {var urlCoverArt = RIVA;}
        else if (artistRadio == 'RIBLJA CORBA') {var urlCoverArt = RIBLJA_CORBA;}
        else if (artistRadio == 'SEVERINA') {var urlCoverArt = SEVERINA;}
        else if (artistRadio == 'SMAK') {var urlCoverArt = SMAK;}
        else if (artistRadio == 'SRDJAN JUL') {var urlCoverArt = SRDJAN_JUL;}
        else if (artistRadio == 'SREBRENA KRILA') {var urlCoverArt = SREBRENA_KRILA;}
        else if (artistRadio == 'STIJENE') {var urlCoverArt = STIJENE;}
        else if (artistRadio == 'SUNCANA STRANA ULICE') {var urlCoverArt = SUNCANA_STRANA_ULICE;}
        else if (artistRadio == 'TAJCI') {var urlCoverArt = TAJCI;}
        else if (artistRadio == 'TEREZA KESOVIJA') {var urlCoverArt = TEREZA_KESOVIJA;}
        else if (artistRadio == 'TIFA') {var urlCoverArt = TIFA}
        else if (artistRadio == 'TIME') {var urlCoverArt = TIME;}
        else if (artistRadio == 'TONY MONTANO') {var urlCoverArt = TONY_MONTANO;}
        else if (artistRadio == 'TUTTI FRUTTI') {var urlCoverArt = TUTTI_FRUTTI;}
        else if (artistRadio == 'U SKRIPCU') {var urlCoverArt = U_SKRIPCU;}
        else if (artistRadio == 'VAJTA') {var urlCoverArt = VAJTA;}
        else if (artistRadio == 'VALENTINO') {var urlCoverArt = VALENTINO;}
        else if (artistRadio == 'VAN GOGH') {var urlCoverArt = VAN_GOGH;}
        else if (artistRadio == 'VIDEOSEX') {var urlCoverArt = VIDEOSEX;}
        else if (artistRadio == 'VIKTORIJA') {var urlCoverArt = VIKTORIJA;}
        else if (artistRadio == 'VJESTICE') {var urlCoverArt = VJESTICE;}
        else if (artistRadio == 'VLADO KALEMBER') {var urlCoverArt = VLADO_KALEMBER;}
        else if (artistRadio == 'XENIA') {var urlCoverArt = XENIA;}
        else if (artistRadio == 'YU GRUPA'){var urlCoverArt = YU_GRUPA;}
        else if (artistRadio == 'YU ROCK MISIJA') {var urlCoverArt = YU_ROCK_MISIJA;}
        else if (artistRadio == 'ZABRANJENO PUSENJE') {var urlCoverArt = ZABRANJENO_PUSENJE;}
        else if (artistRadio == 'ZANA') {var urlCoverArt = ZANA;}
        else if (artistRadio == 'ZDRAVKO COLIC') {var urlCoverArt = ZDRAVKO_COLIC;}
        else if (artistRadio == 'ZELJKO BEBEK') {var urlCoverArt = ZELJKO_BEBEK;}
        else if (artistRadio == 'ZLATKO PEJAKOVIC') {var urlCoverArt = ZLATKO_PEJAKOVIC;}
        else {var urlCoverArt = DEFAULT_COVER_ART;}

        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {
            if (this.readyState === 4 && this.status === 200) {
                    var data = JSON.parse(this.responseText);    
                    var artworkUrl100 = (data.resultCount) ? data.results[0].artworkUrl100 : urlCoverArt;
        document.querySelectorAll('#historicSong article .cover-historic')[n].style.backgroundImage = 'url(' + artworkUrl100 + ')';
    }
        var music = info.song.replace(/&apos;/g, '\'');var songHist = music.replace(/&amp;/g, '&');
        var artist = info.artist.replace(/&apos;/g, '\'');var artistHist = artist.replace(/&amp;/g, '&');
        
        $songName[n].innerHTML = songHist;$artistName[n].innerHTML = artistHist;
        $historicDiv[n].classList.add('animated');$historicDiv[n].classList.add('slideInRight');}
        
        xhttp.open('GET', 'https://itunes.apple.com/search?term=' + info.artist + ' ' + info.song + '&media=music&limit=1', true);
        xhttp.send();

        setTimeout(function () {for (var j = 0; j < 2; j++) {    $historicDiv[j].classList.remove('animated');    $historicDiv[j].classList.remove('slideInRight');}}, 2000);
    }

       // Ковери на изведувачи - доле 
       this.refreshCover = function (song = '', artist) {
        const FRATELLO = "img/izveduvaci/212.jpg";
        const STAVI_PRAVU_STVAR = 'img/izveduvaci/213.jpg';
        const STO_SI_U_KAVU_STAVILA = 'img/izveduvaci/214.jpg';
        const OBICNA_LJUBAVNA_PJESMA = 'img/izveduvaci/215.jpg';
        const A_STA_DA_RADIM = 'img/izveduvaci/216.jpg';
        const DIGNI_ME_VISOKO = 'img/izveduvaci/217.jpg';
        const OTKAZAN_LET = 'img/izveduvaci/218.jpg';
        const LJUBAV_PREKO_ZICE = 'img/izveduvaci/219.jpg';
        const MIKI_MIKI = 'img/izveduvaci/220.jpg';
        const DAO_SAM_TI_DUSU = 'img/izveduvaci/221.jpg';
        const S_TOBOM_NASAO_SAM_SRECU = 'img/izveduvaci/222.jpg';
        const KESTENI = 'img/izveduvaci/223.jpg';
        const POSLE_9_GODINA = 'img/izveduvaci/224.jpg';
        const SANJA = 'img/izveduvaci/225.jpg';
        const EJ_STA_MI_RADIS = 'img/izveduvaci/226.jpg';
        const NEK_TI_JUTRO_MIRISE_NA_MENE = 'img/izveduvaci/227.jpg';
        const DOJDJI_U_5_DO_5 = 'img/izveduvaci/228.jpg';
        const ZEMLJO_MOJA_FT_ISMETA_KRAVAC = 'img/izveduvaci/229.jpg';
        const ANDJELI_NAS_ZOVU_DA_IM_SKINEMO_KRILA = 'img/izveduvaci/230.jpg';
        const O_MLADOSTI = 'img/izveduvaci/231.jpg';
        const SVE_STO_ZNAS_O_MENI = 'img/izveduvaci/232.jpg';
        const DEVOJKA_IZ_MOGA_KRAJA = 'img/izveduvaci/233.jpg';
        const PROLJECE_BEZ_TEBE = 'img/izveduvaci/234.jpg';
        const ZAGRLI_ME1 = 'img/izveduvaci/235.jpg';
        const DEVOJKA_BROJ_8 = 'img/izveduvaci/236.jpg';
        const PAKLENI_VOZACI = 'img/izveduvaci/237.jpg';
        const ZA_LJUBAV_TREBA_IMAT_DUSU = 'img/izveduvaci/238.jpg';
        const VOLJELA_ME_NIJE_NI_JEDNA = 'img/izveduvaci/239.jpg';
        const USNE_VRELE_VISNJE = 'img/izveduvaci/240.jpg';
        const AKO_ZNAS_BILO_STA = 'img/izveduvaci/241.jpg';
        const BALKAN = 'img/izveduvaci/242.jpg';
        const GRACIJA = 'img/izveduvaci/243.jpg';
        const MARINA = 'img/izveduvaci/244.jpg';
        const LJEPE_ZENE_PROLAZE_KROZ_GRAD = 'img/izveduvaci/245.jpg';
        const NOC_BEZ_SNA = 'img/izveduvaci/246.jpg';
        const DA_TE_VIDIM_GOLU = 'img/izveduvaci/247.jpg';
        const SAMO_NAM_JE_LJUBAV_POTREBNA = 'img/izveduvaci/248.jpg';
        const PLAVI_SAFIRU = 'img/izveduvaci/249.jpg';
        const OD_KAD_TEBE_VOLIM = 'img/izveduvaci/250.jpg';
        const VERUJEM_NE_VERUJEM = 'img/izveduvaci/251.jpg';
        const GODINE_PROLAZE = 'img/izveduvaci/252.jpg';
        const TISINA = 'img/izveduvaci/253.jpg';
        const RUSKI_VOZ = 'img/izveduvaci/254.jpg';
        const VESELA_PESMA = 'img/izveduvaci/255.jpg';
        const ZIVOT_JE_NEKAD_SIV_NEKAD_ZUT = 'img/izveduvaci/256.jpg';
        const GORE_DOLE = 'img/izveduvaci/257.jpg';
        const TI_SE_LJUBIS = 'img/izveduvaci/258.jpg';
        const SA_DRUGE_STRANE = 'img/izveduvaci/259.jpg';
        const ZAZMURI = 'img/izveduvaci/260.jpg';
        const DO_BEOGRADA = 'img/izveduvaci/261.jpg';
        const VIDI_STA_SAM_TI_URADIO_OD_PESME_MAMA = 'img/izveduvaci/262.jpg';
        const SARENE_PILULE = 'img/izveduvaci/264.jpg';
        const VEK = 'img/izveduvaci/265.jpg';
        const TAMARA = 'img/izveduvaci/266.jpg';
        const POLJUBI_ME = 'img/izveduvaci/267.jpg';
        const LEPA_JANJA_RIBAREVA_KCI = 'img/izveduvaci/268.jpg';
        const ZMAJ_OD_NOCAJA = 'img/izveduvaci/269.jpg';
        const MUZIKA_NA_STRUJU = 'img/izveduvaci/270.jpg';
        const OVO_JE_BALKAN = 'img/izveduvaci/271.jpg';
        const JOS_TE_VOLIM1 = 'img/izveduvaci/272.jpg';
        const NA_VRHOVIMA_PRSTIJU = 'img/izveduvaci/273.jpg';
        const KAD_HODAS = 'img/izveduvaci/274.jpg';
        const MOJI_SU_DRUGOVI = 'img/izveduvaci/275.jpg';
        const GDE_SI = 'img/izveduvaci/276.jpg';
        const BAM_BAM_BAM = 'img/izveduvaci/277.jpg';
        const NEKA_SVEMIR_CUJE_NEMIR = 'img/izveduvaci/278.jpg';
        const JEDINO_TO_SE_ZOVE_LJUBAV = 'img/izveduvaci/279.jpg';
        const KRV_SRECA_SUZE_I_ZNOJ = 'img/izveduvaci/280.jpg';
        const RUDI = 'img/izveduvaci/281.jpg';
        const BRA_ZIL = 'img/izveduvaci/282.jpg';
        const HAJDE_DA_UZMEMO_NEKI_DOBAR_AUTO = 'img/izveduvaci/283.jpg';
        const BADEMI_I_SO_FT_BAJAGA = 'img/izveduvaci/284.jpg';
        const DA_PRICAMO_O_LJUBAVI = 'img/izveduvaci/285.jpg';
        const IPAK_POZELIM_NEKO_PISMO = 'img/izveduvaci/286.jpg';
        const BITANGA_I_PRINCEZA = 'img/izveduvaci/287.jpg';
        const SVE_CE_TO_MILA_MOJA_PREKRITI_RUZMARIN = 'img/izveduvaci/288.jpg';
        const NOCAS_JE_KO_LUBENICA = 'img/izveduvaci/289.jpg';
        const PLJUNI_I_ZAPEVAJ_MOJA_JUGOSLAVIJO = 'img/izveduvaci/290.jpg';
        const A_I_TI_ME_IZNEVJERI = 'img/izveduvaci/291.jpg';
        const RUZICA_SI_BILA = 'img/izveduvaci/292.jpg';
        const HAJDEMO_U_PLANINE = 'img/izveduvaci/293.jpg';
        const JER_KAD_OSTARIS = 'img/izveduvaci/294.jpg';
        const LAZES_ZLATO = 'img/izveduvaci/295.jpg';
        const ZA_ESMU = 'img/izveduvaci/296.jpg';
        const LIPE_CVATU = 'img/izveduvaci/297.jpg';
        const PADAJU_ZVEZDE = 'img/izveduvaci/298.jpg';
        const DA_TE_BOGDO_NEVOLIM = 'img/izveduvaci/299.jpg';
        const MENI_SE_NESPAVA = 'img/izveduvaci/300.jpg';
        const AKO_MOZES_ZABORAVI = 'img/izveduvaci/301.jpg';
        const U_VREME_OTKAZANIH_LETOVA = 'img/izveduvaci/302.jpg';
        const DOZIVJETI_STOTU = 'img/izveduvaci/303.jpg';
        const ZAZMURI_I_BROJ_DO_100 = 'img/izveduvaci/304.jpg';
        const PRISTAO_SAM_BICU_SVE_STO_HOCE = 'img/izveduvaci/305.jpg';
        const HA_HA_HA_SVI_MARS_NA_PLJES = 'img/izveduvaci/306.jpg';
        const KAD_BI_BIO_BIJELO_DUGME = 'img/izveduvaci/307.jpg';
        const SELMA = 'img/izveduvaci/308.jpg';
        const IMA_NEKA_TAJNA_VEZA = 'img/izveduvaci/309.jpg';
        const DA_SAM_PEKAR = 'img/izveduvaci/310.jpg';
        const NE_SPAVAJ_MALA_MOJA_MUZIKA_DOK_SVIRA = 'img/izveduvaci/311.jpg';
        const AKO_IMA_BOGA = 'img/izveduvaci/312.jpg';
        const NAPILE_SE_ULICE = 'img/izveduvaci/313.jpg';
        const STA_IMA_NOVO = 'img/izveduvaci/314.jpg';
        const NAKON_SVIH_OVIH_GODINA = 'img/izveduvaci/315.jpg';
        const CIRIBIRIBELA = 'img/izveduvaci/316.jpg';
        const DJURDJEVDAN = 'img/izveduvaci/317.jpg';
        const EVO_ZAKLECU_SE = 'img/izveduvaci/318.jpg';
        const IZGLEDALA_JE_MALO_CUDNO_U_KAPUTU = 'img/izveduvaci/319.jpg';
        const LOSE_VINO1 = 'img/izveduvaci/320.jpg';
        const SANJAO_SAM_NOCAS_DA_TE_NEMAM = 'img/izveduvaci/321.jpg';
        const NA_ZADNJEM_SEDISTU_MOGA_AUTA = 'img/izveduvaci/322.jpg';
        const SVI_MARS_NA_PLES = 'img/izveduvaci/323.jpg';
        const TAKO_TI_JE_MALA_MOJA = 'img/izveduvaci/324.jpg';
        const DOBRO_VAM_JUTRO = 'img/izveduvaci/325.jpg';
        const ZLATNI_DAN = 'img/izveduvaci/326.jpg';
        const MILO_MOJE = 'img/izveduvaci/327.jpg';
        const UZALUD_ME_PODSECAS = 'img/izveduvaci/328.jpg';
        const STO_JE_SA_PRINCEZOM_MOJE_VRELE_MLADOSTI = 'img/izveduvaci/329.jpg';
        const KO_SAM_BEZ_TEBE = 'img/izveduvaci/330.jpg';
        const EMILY = 'img/izveduvaci/331.jpg';
        const KUDA_IDU_IZGUBLJENE_DEVOJKE = 'img/izveduvaci/332.jpg';
        const PRODALA_ME_TI = 'img/izveduvaci/333.jpg';
        const DOK_SVIRA_RADIO = 'img/izveduvaci/334.jpg';
        const DALEKO_FT_KEMALMONTENO = 'img/izveduvaci/335.jpg';
        const MI_SMO_JACI_I_OD_SUDBINE = 'img/izveduvaci/336.jpg';
        const U_DOBRU_I_ZLU = 'img/izveduvaci/337.jpg';
        const ELOIS = 'img/izveduvaci/338.jpg';
        const TUGA_TI_I_JA = 'img/izveduvaci/339.jpg';
        const TO_MI_RADI = 'img/izveduvaci/340.jpg';
        const NEKAKO_S_PROLJECA_FT_KEMAL_MONTENO = 'img/izveduvaci/341.jpg';
        const MOJE_NAJMILIJE = 'img/izveduvaci/342.jpg';
        const TUGO_NESRECO = 'img/izveduvaci/343.jpg';
        const ZOVU_NAS_ULICE = 'img/izveduvaci/345.jpg';
        const BJEZI_KISO_S_PROZORA = 'img/izveduvaci/346.jpg';
        const TAMO_GDE_LJUBAV_POCINJE = 'img/izveduvaci/347.jpg';
        const TVOGA_SRCA_VRATA = 'img/izveduvaci/348.jpg';
        const DIRLIJA = 'img/izveduvaci/349.jpg';
        const IMAM_NEKE_FORE = 'img/izveduvaci/350.jpg';
        const VOLIO_BI_DA_SI_TU = 'img/izveduvaci/351.jpg';
        const SAMPANJSKI_POLJUBAC = 'img/izveduvaci/352.jpg';
        const DA_MI_JE_DO_NJE = 'img/izveduvaci/353.jpg';
        const STIZU_ME_SECANJA = 'img/izveduvaci/354.jpg';
        const IMA_NESTO_OD_SRCA_DO_SRCA = 'img/izveduvaci/355.jpg';
        const AKO_AKO = 'img/izveduvaci/356.jpg';
        const SVIDJA_MI_SE_OVA_STVAR = 'img/izveduvaci/357.jpg';
        const PRINCIPESSA = 'img/izveduvaci/358.jpg';
        const NEMA_VISE_VREMENA = 'img/izveduvaci/359.jpg';
        const S_TVOJIH_USANA = 'img/izveduvaci/360.jpg';
        const FLOYD = 'img/izveduvaci/361.jpg';
        const JA_HOCU_ZIVOT = 'img/izveduvaci/362.jpg';
        const NOC_JE_PREKRASNA = 'img/izveduvaci/363.jpg';
        const DZULI = 'img/izveduvaci/364.jpg';
        const NEKA_MI_NE_SVANE = 'img/izveduvaci/365.jpg';
        const DA_JE_SALDJE_ZASPATI = 'img/izveduvaci/366.jpg';
        const ULICA_JORGOVANA = 'img/izveduvaci/367.jpg';
        const JA_BIH_DA_PEVAM = 'img/izveduvaci/368.jpg';
        const JULIJA = 'img/izveduvaci/369.jpg';
        const LETNJE_KISE = 'img/izveduvaci/370.jpg';
        const OAZA_SNOVA = 'img/izveduvaci/371.jpg';
        const SOBA_23 = 'img/izveduvaci/372.jpg';
        const PROGRAM_TVOG_KOMPJUTERA = 'img/izveduvaci/373.jpg';
        const VOLI_ME_JOS_OVU_NOC = 'img/izveduvaci/374.jpg';
        const JA_SAM_LAZLJIVA = 'img/izveduvaci/375.jpg';
        const U_RITMU_ME_OKRENI = 'img/izveduvaci/376.jpg';
        const TI_SI_MI_U_MISLIMA = 'img/izveduvaci/377.jpg';
        const TEBI_PRIPADAM = 'img/izveduvaci/378.jpg';
        const LJUBAV_SE_ZOVE_IMENOM_TVOIM = 'img/izveduvaci/379.jpg';
        const NECU_DA_ZNAM_ZA_NIKOG_OSIM_TEBE = 'img/izveduvaci/380.jpg';
        const JACE_MANIJACE = 'img/izveduvaci/381.jpg';
        const UMRI_PRIJE_SMRTI = 'img/izveduvaci/382.jpg';
        const SREDINOM = 'img/izveduvaci/383.jpg';
        const MOJ_JE_ZIVOT_SVICARSKA = 'img/izveduvaci/384.jpg';
        const SVE_JE_LAZ = 'img/izveduvaci/385.jpg';
        const GODINAMA = 'img/izveduvaci/386.jpg';
        const KAD_SI_REKLA_DA_ME_VOLIS = 'img/izveduvaci/387.jpg';
        const HITNA = 'img/izveduvaci/388.jpg';
        const DA_JE_TUGA_SNIJEG = 'img/izveduvaci/389.jpg';
        const KREMEN = 'img/izveduvaci/390.jpg';
        const KAD_COVIJEK_VOLI_ZENU = 'img/izveduvaci/391.jpg';
        const STA_TI_ZNACIM_JA = 'img/izveduvaci/392.jpg';
        const DANAS_SAM_OK = 'img/izveduvaci/393.jpg';
        const BOSNOM_BEHAR_PROBEHARAO = 'img/izveduvaci/394.jpg';
        const OBICNA_LJUBAVNAPJESMA = 'img/izveduvaci/395.jpg';
        const ASTA_DA_RADIM = 'img/izveduvaci/396.jpg';
        const DIGNI_MEVISOKO = 'img/izveduvaci/397.jpg';
        const FRAT_ELLO = 'img/izveduvaci/398.jpg';
        const STAVI_PRAVUSTVAR = 'img/izveduvaci/399.jpg';
        const STA_SI_MI_UKAVU_STAVILA = 'img/izveduvaci/400.jpg';
        const NESTO_LIJEPO_TREBA_DA_SE_DESI = 'img/izveduvaci/401.jpg';
        const MJESECINA = 'img/izveduvaci/402.jpg';
        const JEL_SARAJEVO_GDE_JE_NEKAD_BILO = 'img/izveduvaci/403.jpg';
        const KADZAMIRISUJORGOVANIFTVESNA_ZMIJANAC = 'img/izveduvaci/404.jpg';
        const ZAR_JE_TO_SVE_STO_IMAM_OD_TEBE = 'img/izveduvaci/405.jpg';
        const JA_POTPUNO_TRIJEZAN_UMIREM = 'img/izveduvaci/406.jpg';
        const NE_ZOVI_ME_NA_GRIJEH = 'img/izveduvaci/407.jpg';
        const NEMAM_JA_18_GODINA = 'img/izveduvaci/408.jpg';
        const KOKUZNA_VREMENA = 'img/izveduvaci/409.jpg';
        const JA_SAM_NA_TE_NAVIKO = 'img/izveduvaci/410.jpg';
        const UCINI_MI_PRAVU_STVAR = 'img/izveduvaci/411.jpg';
        const SA_MOJIH_USANA = 'img/izveduvaci/412.jpg';
        const DA_SUTIS = 'img/izveduvaci/413.jpg';
        const OTKRIT_CU_TI_TAJNU = 'img/izveduvaci/414.jpg';
        const DESET_MLADJA = 'img/izveduvaci/415.jpg';
        const OSTAT_CE_ISTINE_DVIJE = 'img/izveduvaci/416.jpg';
        const AKO_ME_IKADA_SRETNES = 'img/izveduvaci/417.jpg';
        const ZABORAVI = 'img/izveduvaci/418.jpg';
        const MOJA_BOGDA_SNA = 'img/izveduvaci/419.jpg';
        const BASKA_TI = 'img/izveduvaci/420.jpg';
        const SMIJEHOM_STRAH_POKRIJEM = 'img/izveduvaci/421.jpg';
        const NEK_PADAJU_CUSKIJE = 'img/izveduvaci/422.jpg';
        const ISPOCETKA = 'img/izveduvaci/423.jpg';
        const SVE_DOK_TE_BUDE_IMALO = 'img/izveduvaci/424.jpg';
        const LAZU_ME = 'img/izveduvaci/425.jpg';
        const LELO = 'img/izveduvaci/426.jpg';
        const TREBAM_TE_MARIJA = 'img/izveduvaci/427.jpg';
        const KAKO_SI_TOPLA_I_MILA = 'img/izveduvaci/428.jpg';
        const KRIVO_JE_MORE = 'img/izveduvaci/429.jpg';
        const JEDINA_MOJA = 'img/izveduvaci/430.jpg';
        const ZAUVJEK_TVOJ = 'img/izveduvaci/431.jpg';
        const VOLI_TE_TVOJA_ZVER = 'img/izveduvaci/432.jpg';
        const OSTANI_UZ_MENE = 'img/izveduvaci/433.jpg';
        const BAMBINA = 'img/izveduvaci/434.jpg';
        const DANI_LJUBAVI = 'img/izveduvaci/435.jpg';
        const IVONA = 'img/izveduvaci/436.jpg';
        const JAGODE_I_COKOLADA = 'img/izveduvaci/437.jpg';
        const PRICAJ_MI_O_LJUBAVI = 'img/izveduvaci/438.jpg';
        const ANDJELA_MOJA_JE_DRAGA_VESTICA = 'img/izveduvaci/439.jpg';
        const BOZA_ZVANI_PUB = 'img/izveduvaci/440.jpg';
        const DEVOJKA_SA_CARDAS_NOGAMA = 'img/izveduvaci/441.jpg';
        const DIVLJI_BADEM = 'img/izveduvaci/442.jpg';
        const D_MOLL = 'img/izveduvaci/443.jpg';
        const JA_LUZER = 'img/izveduvaci/444.jpg';
        const JAROSLAVA_PRINCEZO_JAVI_SE = 'img/izveduvaci/445.jpg';
        const LEPA_PROTINA_KCI = 'img/izveduvaci/446.jpg';
        const LJERKA = 'img/izveduvaci/447.jpg';
        const NE_LOMITE_MI_BAGRENJE = 'img/izveduvaci/448.jpg';
        const NE_VOLIM_JANUAR = 'img/izveduvaci/449.jpg';
        const NEKI_NOVI_KLINCI = 'img/izveduvaci/450.jpg';
        const NEVERNIK = 'img/izveduvaci/451.jpg';
        const NIKAD_KAO_BANE = 'img/izveduvaci/452.jpg';
        const OLELOLE = 'img/izveduvaci/453.jpg';
        const OPROSTI_MI_KATRIN = 'img/izveduvaci/454.jpg';
        const PA_DOBRO_GDE_SI_TI = 'img/izveduvaci/455.jpg';
        const PORTRET_MOG_ZIVOTA = 'img/izveduvaci/456.jpg';
        const PROVINCIJALKA = 'img/izveduvaci/457.jpg';
        const PRVA_LJUBAV = 'img/izveduvaci/458.jpg';
        const RINGISPIL = 'img/izveduvaci/459.jpg';
        const SIN_JEDINAC = 'img/izveduvaci/460.jpg';
        const SLABO_DIVANIM_MADZARSKI = 'img/izveduvaci/461.jpg';
        const SLOVENSKA = 'img/izveduvaci/462.jpg';
        const SVIRAJTE_MI_JESEN_STIZE_DUNJO_MOJA = 'img/izveduvaci/463.jpg';
        const USPAVANKA_ZA_DECAKA = 'img/izveduvaci/464.jpg';
        const OLIVERA = 'img/izveduvaci/465.jpg';
        const SJAJ_U_TAMI = 'img/izveduvaci/466.jpg';
        const SAKOM_O_STOL = 'img/izveduvaci/467.jpg';
        const JA_NOCAS_UMIREM = 'img/izveduvaci/468.jpg';
        const KRIVI_LJUDI = 'img/izveduvaci/469.jpg';
        const MALO_MI_ZA_SRICU_TRIBA = 'img/izveduvaci/470.jpg';
        const MARIJA_MAGDALENA = 'img/izveduvaci/471.jpg';
        const MORAM = 'img/izveduvaci/472.jpg';
        const PETAK = 'img/izveduvaci/473.jpg';
        const TO = 'img/izveduvaci/474.jpg';
        const ZELJO_MOJA = 'img/izveduvaci/475.jpg';
        const NI_DA_MORA_NESTANE = 'img/izveduvaci/476.jpg';
        const STAJE_OD_MENE_OSTALO = 'img/izveduvaci/477.jpg';
        const IMA_LI_NADE_ZA_NAS_FT_ANDJELA_ZECIC = 'img/izveduvaci/478.jpg';
        const PISI_MI = 'img/izveduvaci/479.jpg';
        const PRODJE_OVAJ_DAN = 'img/izveduvaci/480.jpg';
        const PAR_GODINA_ZA_NAS = 'img/izveduvaci/481.jpg';
        const SRCE = 'img/izveduvaci/482.jpg';
        const OCI_BOJE_MEDA = 'img/izveduvaci/483.jpg';
        const TI_SI_SAV_MOJ_BOL = 'img/izveduvaci/484.jpg';
        const KRUG = 'img/izveduvaci/485.jpg';
        const DA_SI_TAKO_JAKA = 'img/izveduvaci/486.jpg';
        const BEJBE_TI_NISI_TU = 'img/izveduvaci/487.jpg';
        const IGRA_ROCK_NN_ROLL_CELA_JUGOSLAVIJA = 'img/izveduvaci/488.jpg';
        const MALA_MALA_MALA_GRUPA_PEDERA = 'img/izveduvaci/489.jpg';
        const PARANOJA = 'img/izveduvaci/490.jpg';
        const STO_JA_VOLIM_TAJ_SEX = 'img/izveduvaci/491.jpg';
        const A_SADA_IDEM_FT_TIFA = 'img/izveduvaci/492.jpg';
        const BOJE_SU_U_NAMA = 'img/izveduvaci/493.jpg';
        const DOCI_CU_TI_U_SNOVIMA = 'img/izveduvaci/494.jpg';
        const LIJEPO_LIJEPO_NEOPISIVO = 'img/izveduvaci/495.jpg';
        const NJEZNO_NJEZNO_NJEZNIJE = 'img/izveduvaci/496.jpg';
        const PJEVAJMO_DO_ZORE = 'img/izveduvaci/497.jpg';
        const ZAMISLI_ZIVOT_U_RITMU_MUZIKE_ZA_PLES = 'img/izveduvaci/498.jpg';
        const DOBRE_VIBRACIJE = 'img/izveduvaci/499.jpg';
        const SRCE_NA_CESTI = 'img/izveduvaci/500.jpg';
        const MI_NISMO_SAMI = 'img/izveduvaci/501.jpg';
        const SJECAM_SE_PRVOG_POLJUPCA = 'img/izveduvaci/502.jpg';
        const LJUBAV_JE_ZAKON = 'img/izveduvaci/503.jpg';
        const MACKA = 'img/izveduvaci/504.jpg';
        const ZABORAVIT_CU_SVE = 'img/izveduvaci/505.jpg';
        const ZVONI_TELEFON = 'img/izveduvaci/506.jpg';
        const VOLIM_TE_BUDALO_MALA = 'img/izveduvaci/507.jpg';
        const ZAGRLJENI = 'img/izveduvaci/508.jpg';
        const PAMTIM_SAMO_SRETNE_DANE = 'img/izveduvaci/509.jpg';
        const ON_ME_VOLI_NA_SVOJ_NACIN = 'img/izveduvaci/510.jpg';
        const VINO_I_GITARE = 'img/izveduvaci/511.jpg';
        const CINIM_PRAVU_STVAR = 'img/izveduvaci/512.jpg';
        const DVIJE_DUSE = 'img/izveduvaci/513.jpg';
        const ISPOD_MOGA_PRAMCA = 'img/izveduvaci/514.jpg';
        const OVO_MI_JE_SKOLA = 'img/izveduvaci/515.jpg';
        const SUVISE_SAM_NJEN = 'img/izveduvaci/516.jpg';
        const BAS_TI_LIJEPO_STOJE_SUZE = 'img/izveduvaci/517.jpg';
        const HEJ_KAKO_SI = 'img/izveduvaci/518.jpg';
        const JAVI_SE = 'img/izveduvaci/519.jpg';
        const KAD_DODJE_OKTOBAR = 'img/izveduvaci/520.jpg';
        const KAO_DOMINE = 'img/izveduvaci/521.jpg';
        const CUVAM_NOC_OD_BUDNIH = 'img/izveduvaci/522.jpg';
        const FEMME_FATALE = 'img/izveduvaci/523.jpg';
        const KAO_KAKAO = 'img/izveduvaci/524.jpg';
        const MAMURNI_LJUDI = 'img/izveduvaci/525.jpg';
        const SKOPJE = 'img/izveduvaci/526.jpg';
        const UCI_ME_MAJKO_KARAJ_ME = 'img/izveduvaci/527.jpg';
        const CUKNI_VO_DRVO = 'img/izveduvaci/528.jpg';
        const IMA_VREMENA = 'img/izveduvaci/529.jpg';
        const SANJAO_SAM_MOJ_RUZICU = 'img/izveduvaci/530.jpg';
        const GUTLJAJ_VINA = 'img/izveduvaci/531.jpg';
        const JEL_ZBOG_NJE = 'img/izveduvaci/532.jpg';
        const KOKOLO = 'img/izveduvaci/533.jpg';
        const LJUBE_SE_DOBRI_LOSI_ZLI = 'img/izveduvaci/534.jpg';
        const MINUT_SRCA_TVOG = 'img/izveduvaci/535.jpg';
        const OKO_MOJE_SANJIVO = 'img/izveduvaci/536.jpg';
        const OPIJUM = 'img/izveduvaci/537.jpg';
        const PUT_PUTUJEM = 'img/izveduvaci/538.jpg';
        const RANO_RANIJE = 'img/izveduvaci/539.jpg';
        const SUZE_BISERNE = 'img/izveduvaci/540.jpg';
        const SVE_BI_SEKE_LJUBILE_MORNARE = 'img/izveduvaci/541.jpg';
        const TAMARA1 = 'img/izveduvaci/542.jpg';
        const AKO_ME_OSTAVIS = 'img/izveduvaci/543.jpg';
        const JA_NEMAM_VISE_RAZLOGA_DA_ZIVIM = 'img/izveduvaci/544.jpg';
        const JEDAN_DAN_ZIVOTA = 'img/izveduvaci/545.jpg';
        const JOS_I_DANAS_TEKU_SUZE_JEDNE_ZENE = 'img/izveduvaci/546.jpg';
        const MALO_MI_JE_JEDAN_ZIVOT_S_TOBOM = 'img/izveduvaci/547.jpg';
        const NIKOGA_NISAM_VOLIO_TAKO = 'img/izveduvaci/548.jpg';
        const OSTALA_SI_UVIJEK_ISTA = 'img/izveduvaci/549.jpg';
        const SVI_PEVAJU_JA_NE_CUJEM = 'img/izveduvaci/550.jpg';
        const TI_SI_PJESMA_MOJE_DUSE = 'img/izveduvaci/551.jpg';
        const DALI_SI_SPAVALA = 'img/izveduvaci/552.jpg';
        const DA_ME_NISI = 'img/izveduvaci/553.jpg';
        const DIGNI_RUKU = 'img/izveduvaci/554.jpg';
        const DODIRNI_ME = 'img/izveduvaci/555.jpg';
        const KAD_ME_POGLEDAS = 'img/izveduvaci/556.jpg';
        const KOTOR = 'img/izveduvaci/557.jpg';
        const SKADARSKA = 'img/izveduvaci/558.jpg';
        const TRUBE = 'img/izveduvaci/559.jpg';
        const TI_SAMO_BUDI_DOVOLJNO_DALEKO = 'img/izveduvaci/560.jpg';
        const OSMIJEH = 'img/izveduvaci/561.jpg';
        const KENOZOIK = 'img/izveduvaci/562.jpg';
        const MALJCHIKI = 'img/izveduvaci/563.jpg';
        const LEJLA = 'img/izveduvaci/564.jpg';
        const LUD_SAM_ZA_TOBOM = 'img/izveduvaci/565.jpg';
        const NEK_NEBO_NAM_SUDI = 'img/izveduvaci/566.jpg';
        const OSTAVI_SUZE_ZA_KRAJ = 'img/izveduvaci/567.jpg';
        const OTKAD_TEBE_NEMA = 'img/izveduvaci/568.jpg';
        const RODJENA_SI_SAMO_ZA_MENE = 'img/izveduvaci/569.jpg';

        const STRAH_ME_DA_TE_VOLIM = 'img/izveduvaci/571.jpg';
        const SVE_LJUBAVI_SU_TUZNE = 'img/izveduvaci/572.jpg';
        const SVI_MOJI_DRUMOVI = 'img/izveduvaci/573.jpg';
        const TI_ZNAS_SVE = 'img/izveduvaci/574.jpg';
        const VOLIO_BI_DA_TE_NE_VOLIM = 'img/izveduvaci/575.jpg';
        const STRANAC_U_NOCI = 'img/izveduvaci/576.jpg';
        const POTRAZI_ME_U_PREDGRADU = 'img/izveduvaci/577.jpg';
        const SAMO_SIMPATIJA = 'img/izveduvaci/578.jpg';
        const ZORA_JE = 'img/izveduvaci/579.jpg';
        const STO_CE_TAJ_COVJEK_TU = 'img/izveduvaci/580.jpg';
        const TESKA_VREMENA_PRIJATELJU_MOJ = 'img/izveduvaci/581.jpg';
        const DOTAKNI_ME_USNAMA = 'img/izveduvaci/582.jpg';
        const RIJEKA_SNOVA = 'img/izveduvaci/583.jpg';
        const SUNCAN_DAN = 'img/izveduvaci/584.jpg';
        const KAVANNA_FT_FIUMENS = 'img/izveduvaci/585.jpg';
        const NAJDRAZE_MOJE = 'img/izveduvaci/586.jpg';
        const PLAVA_KOSULJA = 'img/izveduvaci/587.jpg';
        const SUTI_MOJ_DJECACE_PLAVI = 'img/izveduvaci/588.jpg';
        const ZA_DOBRA_STARA_VREMENA = 'img/izveduvaci/589.jpg';
        const ZNAM = 'img/izveduvaci/590.jpg';
        const BICU_TVOJ = 'img/izveduvaci/591.jpg';
        const BOBANE = 'img/izveduvaci/592.jpg';
        const DODJE_MI_DA_VRISNEM_TVOJE_IME = 'img/izveduvaci/593.jpg';
        const NIJE_ZA_NJU = 'img/izveduvaci/594.jpg'
        const ODLAZIM_A_VOLIM_TE = 'img/izveduvaci/595.jpg';
        const OSLONI_SE_NE_MENE = 'img/izveduvaci/596.jpg';
        const PITAJU_ME_PITAJU = 'img/izveduvaci/597.jpg';
        const POMAGAJTE_DRUGOVI = 'img/izveduvaci/598.jpg';
        const SMEJEM_SE_A_PLAKAO_BIH = 'img/izveduvaci/599.jpg';
        const ZBOG_TEBE_BIH_TUCAO_KAMEN = 'img/izveduvaci/600.jpg';
        const CRNI_PLES = 'img/izveduvaci/601.jpg';
        const DENIS = 'img/izveduvaci/602.jpg';
        const NADJI_ME = 'img/izveduvaci/603.jpg';
        const SAM = 'img/izveduvaci/604.jpg';
        const BROD_U_BOCI = 'img/izveduvaci/605.jpg';
        const CESARICA = 'img/izveduvaci/606.jpg';
        const DVAPUT_SAN_UMRA = 'img/izveduvaci/607.jpg';
        const KAD_MI_DODZES_TI = 'img/izveduvaci/608.jpg';
        const NEBO_MOJE = 'img/izveduvaci/609.jpg';
        const NEDOSTAJES_MI_TI = 'img/izveduvaci/610.jpg';
        const NOCTURNO = 'img/izveduvaci/611.jpg';
        const PISMO_MOJA = 'img/izveduvaci/612.jpg';
        const PRED_TVOJIM_VRATIMA = 'img/izveduvaci/613.jpg';
        const STINE = 'img/izveduvaci/614.jpg';
        const STO_TO_BJESE_LJUBAV = 'img/izveduvaci/615.jpg';
        const SVE_BI_DA_ZA_NJU = 'img/izveduvaci/616.jpg';
        const SVIRAJTE_NOCAS_ZA_MOJU_DUSU = 'img/izveduvaci/617.jpg';
        const TRAG_U_BESKRAJU = 'img/izveduvaci/618.jpg';
        const VJERUJ_U_LJUBAV = 'img/izveduvaci/619.jpg';
        const U_LJUBAV_VJERE_NEMAM_FT_GIBONNI = 'img/izveduvaci/620.jpg';
        const DZENI = 'img/izveduvaci/621.jpg';
        const E_DA_SI_BAREM_NOCAS_OVDJE = 'img/izveduvaci/622.jpg';
        const E_MOJ_SASA = 'img/izveduvaci/623.jpg';
        const JA_SAM_ZA_PLES = 'img/izveduvaci/624.jpg';
        const JESEN_JE = 'img/izveduvaci/625.jpg';
        const MILENA = 'img/izveduvaci/626.jpg';
        const CARTE_BLANCHE = 'img/izveduvaci/627.jpg';
        const BEZ_TEBE = 'img/izveduvaci/628.jpg';
        const DITELINA_S_CETRI_LISTA = 'img/izveduvaci/629.jpg';
        const JEDAN_OD_MNOGIH = 'img/izveduvaci/630.jpg';
        const CALIFORNIA = 'img/izveduvaci/631.jpg';
        const JEANS_GENERACIJA = 'img/izveduvaci/632.jpg';
        const KAKVA_NOC1 = 'img/izveduvaci/633.jpg';
        const DZEMPER_ZA_VINOGRAD = 'img/izveduvaci/634.jpg';
        const KAD_BI_DOSLA_MARIJA = 'img/izveduvaci/635.jpg';
        const OD_DRUGA_DO_DRUGA = 'img/izveduvaci/636.jpg';
        const VINO_NOCI_FT_DEMODE = 'img/izveduvaci/637.jpg';
        const KOLACICI = 'img/izveduvaci/638.jpg';
        const DA_MI_JE_BITI_MORSKI_PAS = 'img/izveduvaci/639.jpg';
        const AKO_JEDNOM_VIDIS_MARIJU = 'img/izveduvaci/640.jpg';
        const KAD_BIH_ZNAO_DA_JE_SAMA = 'img/izveduvaci/641.jpg';
        const AKO_OVO_JE_KRAJ_FT_DAVOR_DRAGOJEVIC = 'img/izveduvaci/642.jpg';
        const APSOLUTNO_TVOJ = 'img/izveduvaci/643.jpg';
        const JA_IMAM_TE_A_KO_DA_NEMAM_TE = 'img/izveduvaci/644.jpg';
        const PRSTEN_I_ZLATNI_LANAC = 'img/izveduvaci/645.jpg';
        const STO_JE_BILO_BILO_JE = 'img/izveduvaci/646.jpg';
        const ZUTE_DUNJE = 'img/izveduvaci/647.jpg';
        const IMA_NEKA_TAJNA_VEZA_ZA_SVE_LJUDE = 'img/izveduvaci/648.jpg';
        const STO_TE_NEMA = 'img/izveduvaci/649.jpg';
        const SVE_SMO_MOGLI_MI = 'img/izveduvaci/650.jpg';
        const JA_SAM_TI_JEDINI_DRUG = 'img/izveduvaci/651.jpg';
        const NA_OBALI = 'img/izveduvaci/652.jpg';
        const SKITNICA = 'img/izveduvaci/653.jpg';
        const DODZI_U_MALI_KAFE = 'img/izveduvaci/654.jpg';
        const GOVOR_TVOGA_TELA = 'img/izveduvaci/655.jpg';
        const LJULJAJ_ME_NEZNO = 'img/izveduvaci/656.jpg';
        const PROBAJ_ME = 'img/izveduvaci/657.jpg';
        const GDE_DA_POBEGNEM = 'img/izveduvaci/658.jpg';
        const MARIJA = 'img/izveduvaci/659.jpg';
        const MOZDA_NEBO_ZNA = 'img/izveduvaci/660.jpg';
        const S_KIM_CEKAS_DAN = 'img/izveduvaci/661.jpg';
        const VINO_CRVENO = 'img/izveduvaci/662.jpg';
        const IVANA = 'img/izveduvaci/663.jpg';
        const DODJI = 'img/izveduvaci/664.jpg';
        const DOK_SI_PORED_MENE = 'img/izveduvaci/665.jpg';
        const GODINE_PROLAZE_NEKA_IDU_BEZ_TEBE = 'img/izveduvaci/666.jpg';
        const JESEN_U_MENI = 'img/izveduvaci/667.jpg';
        const KADA_ME_DOTAKNE = 'img/izveduvaci/668.jpg';
        const KAO_TI = 'img/izveduvaci/669.jpg';
        const LJUBAVNA = 'img/izveduvaci/670.jpg';
        const LUTKA_ZA_BAL = 'img/izveduvaci/671.jpg';
        const MOJA_JE_PJESMA_LAGANA = 'img/izveduvaci/672.jpg';
        const NEDA = 'img/izveduvaci/673.jpg';
        const PROKLETA_NEDELJA = 'img/izveduvaci/674.jpg';
        const SVE_JOS_MIRISE_NA_NJU = 'img/izveduvaci/675.jpg';
        const U_LJUBAV_VJERUJEM = 'img/izveduvaci/676.jpg';
        const UGASI_ME = 'img/izveduvaci/677.jpg';
        const UHVATI_RITAM = 'img/izveduvaci/678.jpg';
        const ZASTAVE = 'img/izveduvaci/679.jpg';
        const STRANICE_DNEVNIKA = 'img/izveduvaci/680.jpg';
        const DOLAZIM_ZA_5_MINUTA = 'img/izveduvaci/681.jpg';
        const NAJ_JACI_OSTAJU = 'img/izveduvaci/682.jpg';
        const POVEDI_ME_U_NOC = 'img/izveduvaci/683.jpg';
        const SVEMU_DODJE_KRAJ = 'img/izveduvaci/684.jpg';
        const TI_I_JA = 'img/izveduvaci/685.jpg';
        const BI_MOGO_DA_MOGU = 'img/izveduvaci/686.jpg';
        const ENA = 'img/izveduvaci/687.jpg';
        const MOJA_PRVA_LJUBAV = 'img/izveduvaci/688.jpg';
        const SAL_OD_SVILE = 'img/izveduvaci/689.jpg';
        const SEJN = 'img/izveduvaci/690.jpg';
        const UZALUD_PITAS = 'img/izveduvaci/691.jpg';
        const LAGANO_UMIREM = 'img/izveduvaci/692.jpg';
        const CEKALA_SAM = 'img/izveduvaci/693.jpg';
        const NE_LOMI_ME = 'img/izveduvaci/694.jpg';
        const RUZMARIN = 'img/izveduvaci/695.jpg';

        const CINI_MI_SE_DA = 'img/izveduvaci/697.jpg';
        const KADA_SANJAMO = 'img/izveduvaci/698.jpg';
        const NEVERNA_SI = 'img/izveduvaci/699.jpg';
        const TO_JE_SUDBINA = 'img/izveduvaci/700.jpg';
        const KAO_PTICA_NA_MOM_DLANU = 'img/izveduvaci/701.jpg';
        const TAJNA_JE_U_TEBI_SKRIVENA = 'img/izveduvaci/702.jpg';
        const ZABORAVLJENI = 'img/izveduvaci/703.jpg';
        const AKO_SU_TO_SAMO_BILE_LAZI = 'img/izveduvaci/704.jpg';
        const BOLJE_BITI_PIJAN_NEGO_STAR = 'img/izveduvaci/705.jpg';
        const KAJA = 'img/izveduvaci/706.jpg';
        const LJUBI_SE_ISTOK_I_ZAPAD = 'img/izveduvaci/707.jpg';
        const LOVAC_I_KOSUTA = 'img/izveduvaci/708.jpg';
        const GRUDI_BALKANSKE = 'img/izveduvaci/709.jpg';
        const NATASA = 'img/izveduvaci/710.jpg';
        const VRATI_SE = 'img/izveduvaci/711.jpg';
        const FRIDA = 'img/izveduvaci/712.jpg';
        const JEDNA_MALA_PLAVA = 'img/izveduvaci/713.jpg';
        const PRINCEZA_FT_DADO_TOPIC = 'img/izveduvaci/714.jpg';
        const ODLAZIM = 'img/izveduvaci/715.jpg';
        const SAVA_TIHO_TECE = 'img/izveduvaci/716.jpg';
        const SUADA = 'img/izveduvaci/717.jpg';
        const ZELENE_SU_BILE_OCI_TE = 'img/izveduvaci/718.jpg';
        const DECKO_AJDE_OLADI = 'img/izveduvaci/719.jpg';
        const SRCE_OD_MEDA = 'img/izveduvaci/720.jpg';
        const TAXI = 'img/izveduvaci/721.jpg';
        const JELENI_UMIRU_SAMI = 'img/izveduvaci/722.jpg';
        const IZ_NEKIH_STARIH_RAZLOGA = 'img/izveduvaci/723.jpg';
        const NE_ZOVI_MAMA_DOKTORA = 'img/izveduvaci/724.jpg';
        const CRNO_BIJELI_SVIJET = 'img/izveduvaci/725.jpg';
        const KISE_JESENJE = 'img/izveduvaci/726.jpg';
        const KORAK_OD_SNA = 'img/izveduvaci/727.jpg';
        const MA_KOG_ME_BOGA_ZA_TEBE_PITAJU = 'img/izveduvaci/728.jpg';
        const MAR_INA = 'img/izveduvaci/729.jpg';
        const MI_PLESEMO = 'img/izveduvaci/730.jpg';
        const MOJ_BIJELI_LABUDE = 'img/izveduvaci/731.jpg';
        const S_VREMENA_NA_VRIJEME = 'img/izveduvaci/732.jpg';
        const UZALUD_VAM_TRUD_SVIRACI = 'img/izveduvaci/733.jpg';
        const ZAUSTAVITE_ZEMLJU = 'img/izveduvaci/734.jpg';
        const AKO_TRAZIS_NEKOGA = 'img/izveduvaci/735.jpg';
        const TU_NOC_KAD_SI_SE_UDAVALA = 'img/izveduvaci/736.jpg';
        const ZBOG_MENE_NE_PLACI = 'img/izveduvaci/737.jpg';
        const LOLA = 'img/izveduvaci/738.jpg';
        const TUZNA_SU_ZELENA_POLJA = 'img/izveduvaci/739.jpg';
        const JA_VOLIM_SAMO_SEBE = 'img/izveduvaci/740.jpg';
        const ANDREA = 'img/izveduvaci/741.jpg';
        const AL_KAPONE = 'img/izveduvaci/742.jpg';
        const AMSTERDAM = 'img/izveduvaci/743.jpg';
        const AVIONU_SLOMICU_TI_KRILA = 'img/izveduvaci/744.jpg';
        const DOBRO_JUTRO = 'img/izveduvaci/745.jpg';
        const DVA_DINARA_DRUZE = 'img/izveduvaci/746.jpg';
        const GDE_SI_U_OVOM_GLUPOM_HOTELU = 'img/izveduvaci/747.jpg';
        const JA_JE_GLEDAM_KAKO_SPAVA = 'img/izveduvaci/748.jpg';
        const JA_SAM_SE_LOZIO_NA_TEBE = 'img/izveduvaci/749.jpg';
        const KAD_HODAS_NE_ZASTAJKUJES = 'img/izveduvaci/750.jpg';
        const KAD_SAM_BIO_MLAD = 'img/izveduvaci/751.jpg';
        const KADA_PADNE_NOC = 'img/izveduvaci/752.jpg';
        const KAKO_JE_LEPO_BITI_GLUP = 'img/izveduvaci/753.jpg';
        const LUTKA_SA_NASLOVNE_STRANE = 'img/izveduvaci/754.jpg';
        const NA_ZAPADU_NISTA_NOVO = 'img/izveduvaci/755.jpg';
        const NEMOJ_DA_IDES_MOJOM_ULICOM = 'img/izveduvaci/756.jpg';
        const NEMOJ_SRECO_NEMOJ_DANAS = 'img/izveduvaci/757.jpg';
        const OSTACU_SLOBODAN = 'img/izveduvaci/758.jpg';
        const OSTANI_DZUBRE_DO_KRAJA = 'img/izveduvaci/759.jpg';
        const POGLEDAJ_DOM_SVOJ_ANDJELE = 'img/izveduvaci/760.jpg';
        const PRAVILA_PRAVILA = 'img/izveduvaci/761.jpg';
        const VOLIM_VOLIM_ZENE = 'img/izveduvaci/762.jpg';
        const COKOLADA = 'img/izveduvaci/763.jpg';
        const DEVOJKO_MALA = 'img/izveduvaci/764.jpg';
        const MALENA = 'img/izveduvaci/765.jpg';
        const ONA_TO_ZNA = 'img/izveduvaci/766.jpg';
        const BACILA_JE_SVE_NIZ_RIJEKU = 'img/izveduvaci/767.jpg';
        const BALADA = 'img/izveduvaci/768.jpg';
        const DA_SAM_JA_NETKO = 'img/izveduvaci/769.jpg';
        const PREDAJ_SE_SRCE = 'img/izveduvaci/770.jpg';
        const SANJAM = 'img/izveduvaci/771.jpg';
        const SVE_OVE_GODINE = 'img/izveduvaci/772.jpg';
        const TI_SI_MI_BILA_NAJ_NAJ = 'img/izveduvaci/773.jpg';
        const DANAS_SAM_LUDA = 'img/izveduvaci/774.jpg';
        const DOBRE_VIBRACIJE_JA_SAM_IZVAN_SEBE = 'img/izveduvaci/775.jpg';
        const GDJE_DUNAV_LJUBI_NEBO = 'img/izveduvaci/776.jpg';
        const MAGLA = 'img/izveduvaci/777.jpg';
        const NOCNA_PTICA = 'img/izveduvaci/778.jpg';
        const O_JEDNOJ_MLADOSTI = 'img/izveduvaci/779.jpg';
        const RUSILA_SAM_MOSTOVE_FT_DINO_DVORNIK = 'img/izveduvaci/780.jpg';
        const CAO_AMORE_FT_VLADO_KALEMBAR = 'img/izveduvaci/781.jpg';
        const POVEDI_ME = 'img/izveduvaci/782.jpg';
        const ANA = 'img/izveduvaci/783.jpg';
        const JA_NISAM_KOCKAR = 'img/izveduvaci/784.jpg';
        const ZAKUNI_SE_LJUBAVI = 'img/izveduvaci/785.jpg';
        const CRNA_DAMA = 'img/izveduvaci/786.jpg';
        const DAIRE = 'img/izveduvaci/787.jpg';
        const KOKETA = 'img/izveduvaci/788.jpg';
        const VOLIO_SAM_TANJU = 'img/izveduvaci/789.jpg';
        const S_VREMENA_NA_VREME = 'img/izveduvaci/790.jpg';
        const KOFER_LJUBAVI = 'img/izveduvaci/791.jpg';
        const RODJENI = 'img/izveduvaci/792.jpg';
        const DALEKO = 'img/izveduvaci/793.jpg';
        const DUSO_MOJA = 'img/izveduvaci/794.jpg';
        const JEDNE_NOCI_U_DECEMBRU = 'img/izveduvaci/795.jpg';
        const NAPISI_JEDNU_LJUBAVNU = 'img/izveduvaci/796.jpg';
        const NIJE_HTJELA = 'img/izveduvaci/797.jpg';
        const OVAKO_NE_MOGU_DALJE = 'img/izveduvaci/798.jpg';
        const VRATIO_SAM_SE_ZIVOTE = 'img/izveduvaci/799.jpg';
        const BOLJE_DA_SAM_DRUGE_LJUBIO = 'img/izveduvaci/800.jpg';
        const COVEK_OD_MEDA = 'img/izveduvaci/801.jpg';
        const HAJDE_DA_SE_VOLIMO = 'img/izveduvaci/802.jpg';
        const NA_RASKRSCU = 'img/izveduvaci/803.jpg';
        const RATNE_IGRE = 'img/izveduvaci/804.jpg';
        const PLAVUSA = 'img/izveduvaci/805.jpg';
        const ZBOG_JEDNE_DIVNE_CRNE_ZENE = 'img/izveduvaci/806.jpg';
        const POKRENI_ME = 'img/izveduvaci/807.jpg';
        const SIZIKA = 'img/izveduvaci/808.jpg';
        const AJDE_AJDE_JASMINA = 'img/izveduvaci/809.jpg';
        const APRIL_U_BEOGRADU = 'img/izveduvaci/810.jpg';
        const CINI_MI_SE_GRMI = 'img/izveduvaci/811.jpg';
        const DA_TI_KAZEM_STA_MI_JE = 'img/izveduvaci/812.jpg';
        const GORI_VATRA = 'img/izveduvaci/813.jpg';
        const KAD_BI_MOJA_BILA = 'img/izveduvaci/814.jpg';
        const MADJARICA = 'img/izveduvaci/815.jpg';
        const MALO_POJACAJ_RADIO = 'img/izveduvaci/816.jpg';
        const PISACU_JOJ_PISMA_DUGA = 'img/izveduvaci/817.jpg';
        const RIJEKA_SUZA_I_NA_NJOJ_LADJA = 'img/izveduvaci/818.jpg';
        const RUSKA = 'img/izveduvaci/819.jpg';
        const SINOC_NISI_BILA_TU = 'img/izveduvaci/820.jpg';
        const STA_MI_RADIS = 'img/izveduvaci/821.jpg';
        const ZIVIS_U_OBLACIMA = 'img/izveduvaci/822.jpg';
        const DA_LI_ZNAS_DA_TE_VOLIM = 'img/izveduvaci/823.jpg';
        const MAKEDONIJA = 'img/izveduvaci/824.jpg';
        const ZDENKA_KOVACICEK = 'img/izveduvaci/825.jpg';
        const SEDAMNEST_TI_JE_GODINA_FT_HARI_MATA_HARI = 'img/izveduvaci/826.jpg';
        const DVIJE_ZVJEZDICE = 'img/izveduvaci/827.jpg';
        const MILION_GODINA = 'img/izveduvaci/828.jpg';
        const MOJ_MALI_JE_OPASAN = 'img/izveduvaci/829.jpg';
        const NEMA_VISE_LJUBAVI = 'img/izveduvaci/830.jpg';
        const MOJA_POSLEDNJA_I_PRVA_LJUBAVI = 'img/izveduvaci/831.jpg';
        const PRIJATELJI_STARI_GDJE_STE = 'img/izveduvaci/832.jpg';
        const DESET_GODINA = 'img/izveduvaci/833.jpg';
        const SRCE_SRNE_KOJA_DRHTI = 'img/izveduvaci/834.jpg';
        const KRILA_LEPTIRA = 'img/izveduvaci/835.jpg';
        const BILO_MI_JE_LIJEPO_S_TOBOM = 'img/izveduvaci/836.jpg';
        const NE_MOZE_TO_TAKO = 'img/izveduvaci/837.jpg';
        const NE_DAJ_MI_DA_GOVORIM_U_SNU = 'img/izveduvaci/838.jpg';
        const OKA_TVOJA_DVA = 'img/izveduvaci/839.jpg';
        const DETEKTIVSKA_PRICA = 'img/izveduvaci/840.jpg';
        const IZNENADI_ME = 'img/izveduvaci/841.jpg';
        const OD_ZLATA_JABUKA = 'img/izveduvaci/842.jpg';
        const TOTALNO_DRUKCIJI_OD_DRUGIH = 'img/izveduvaci/843.jpg';
        const VLAK = 'img/izveduvaci/844.jpg';
        const DUNAVOM_JOS_SIBAJU_VETROVI = 'img/izveduvaci/845.jpg';
        const KOME_SE_RADUJES = 'img/izveduvaci/846.jpg';
        const MORNAR = 'img/izveduvaci/847.jpg';
        const ODLAZIM_DOK_JOS_DRUGI_SPAVAJU = 'img/izveduvaci/848.jpg';
        const CRNI_LEPTIR = 'img/izveduvaci/849.jpg';
        const ZA_MILION_GODINA = 'img/izveduvaci/850.jpg';
        const BALADA_O_PISONJI_I_ZUGI = 'img/izveduvaci/851.jpg';
        const DJEVOJCICE_KOJIMA_MIRISE_KOZA = 'img/izveduvaci/852.jpg';
        const HADZIJA_ILI_BOS = 'img/izveduvaci/853.jpg';
        const JUGO_45 = 'img/izveduvaci/854.jpg';
        const MOZES_IMAT_MOJE_TIJELO = 'img/izveduvaci/855.jpg';
        const ZENICA_BLUES = 'img/izveduvaci/857.jpg';
        const DODIRNI_MI_KOLENA = 'img/izveduvaci/858.jpg';
        const JABUKE_I_VINO = 'img/izveduvaci/859.jpg';
        const MAJSTOR_ZA_POLJUPCE = 'img/izveduvaci/860.jpg';
        const MLADICU_MOJ = 'img/izveduvaci/861.jpg';
        const HAJDE_DA_LUDUJEMO = 'img/izveduvaci/862.jpg';
        const TI_NEMAS_PRAVA_NA_MENE = 'img/izveduvaci/863.jpg';
        const NE_BOJIM_SE_DRUGOVA_TVOGA_FRAJERA = 'img/izveduvaci/864.jpg';
        const STVARI_LAGANE = 'img/izveduvaci/865.jpg';
        const TI_ME_IZLUDUJES = 'img/izveduvaci/866.jpg';
        const A_TI_SI_MANGUP = 'img/izveduvaci/867.jpg';
        const IMA_JEDAN_SVIJET = 'img/izveduvaci/868.jpg';
        const SVE_JE_NEOBICNO_AKO_TE_VOLIM = 'img/izveduvaci/869.jpg';
        const STIPU_GATIBO = 'img/izveduvaci/870.jpg';
        const STO_NE_ZNAM_GDE_SI_SAD = 'img/izveduvaci/871.jpg';
        const VOJAN_POSTA = 'img/izveduvaci/872.jpg';
        const ZNAM_I_OSECAM = 'img/izveduvaci/873.jpg';
        const OZENICES_SE_TI = 'img/izveduvaci/874.jpg';
        const RUKUJU_SE_RUKUJU = 'img/izveduvaci/875.jpg';
        const ZANA_VEJTE_SNEGOVI = 'img/izveduvaci/876.jpg';
        const RAT_I_MIR = 'img/izveduvaci/877.jpg';
        const ARIJA = 'img/izveduvaci/878.jpg';
        const BARAKUDA = 'img/izveduvaci/879.jpg';
        const DAJ_NE_PITAJ = 'img/izveduvaci/880.jpg';
        const SAMO_TERAJ_TI_PO_SVOME = 'img/izveduvaci/881.jpg';
        const VINO_NA_USNAMA = 'img/izveduvaci/882.jpg';
        const TROJE = 'img/izveduvaci/883.jpg';
        const NIKAD_TE_NIKO_NECE_VOLJET_KO_JA = 'img/izveduvaci/884.jpg';
        const NEKO_TE_IMA = 'img/izveduvaci/885.jpg';
        const ZLATNA_RIBICA = 'img/izveduvaci/886.jpg';
        const PONEKAD_NOCU_DOK_SPAVA_GRAD = 'img/izveduvaci/887.jpg';
        const IDU_PTICE_SELICE = 'img/izveduvaci/888.jpg';
        const NE_MOGU_NE_MOGU = 'img/izveduvaci/889.jpg';
        const PILE_MOJE = 'img/izveduvaci/890.jpg';
        const SAMO_SKLOPI_OKICE = 'img/izveduvaci/891.jpg';
        const VOLIM_TE_JOS = 'img/izveduvaci/892.jpg';
        const IZGLEDA_DA_MI_SMO_SAMI = 'img/izveduvaci/893.jpg';
        const KOLIKO_IMAS_GODINA = 'img/izveduvaci/894.jpg';
        const NOVE_GODINE = 'img/izveduvaci/895.jpg';
        const O_JE = 'img/izveduvaci/896.jpg';
        const SIDJI_DO_REKE = 'img/izveduvaci/897.jpg';
        const JUZNJACI = 'img/izveduvaci/898.jpg';
        const OKANO = 'img/izveduvaci/899.jpg';
        const PRAVA_STVAR = 'img/izveduvaci/900.jpg';
        const PUSI_PUSTI_MODU = 'img/izveduvaci/901.jpg';
        const TI_MOZES_SVE = 'img/izveduvaci/902.jpg';
        const TI_SI_MI_U_KRVI = 'img/izveduvaci/903.jpg';
        const AJDE_AJDE_IDI = 'img/izveduvaci/904.jpg';
        const HOTEL_BALKAN = 'img/izveduvaci/905.jpg';
        const KRASIVA = 'img/izveduvaci/906.jpg';
        const NOC_MI_TE_DUGUJE = 'img/izveduvaci/907.jpg';
        const OJ_DEVOJKO_SELEN_VELEN = 'img/izveduvaci/908.jpg';
        const JEDINA = 'img/izveduvaci/909.jpg';
        const LOSE_VINO = 'img/izveduvaci/910.jpg';
        const PJEVAM_DANJU_PJEVAM_NOCU = 'img/izveduvaci/911.jpg';
        const ZVAO_SAM_JE_EMILI = 'img/izveduvaci/912.jpg';
        const CAJE_SUKARIJE = 'img/izveduvaci/913.jpg';
        const CIJA_JE_ONO_ZVIJEZDA = 'img/izveduvaci/914.jpg';
        const E_DRAGA_DRAGA = 'img/izveduvaci/915.jpg';
        const GLAVO_LUDA = 'img/izveduvaci/916.jpg';
        const JEDNA_ZIMA_SA_KRISTINOM = 'img/izveduvaci/917.jpg';
        const MASLINASTO_ZELENA = 'img/izveduvaci/918.jpg';
        const MASTILO_I_VODA = 'img/izveduvaci/919.jpg';
        const NEGDJE_NA_DNU_SRCA = 'img/izveduvaci/920.jpg';
        const PRODUZI_DALJE = 'img/izveduvaci/921.jpg';
        const STANICA_PODLUGOVI = 'img/izveduvaci/922.jpg';
        const ZAGRLI_ME = 'img/izveduvaci/923.jpg';
        const ZBOG_TEBE = 'img/izveduvaci/924.jpg';
        const DA_JE_SRECE_BILO = 'img/izveduvaci/925.jpg';
        const KUCKA_NEVERNA = 'img/izveduvaci/926.jpg';
        const MENE_TJERA_NEKI_VRAG = 'img/izveduvaci/927.jpg';
        const OPROSTI_MI_STO_TE_VOLIM = 'img/izveduvaci/928.jpg';
        const TIJANA = 'img/izveduvaci/929.jpg';
        const SINOC_SAM_POLA_KAFANE_POPIO = 'img/izveduvaci/930.jpg';
        const OVE_NOCI_JEDNA_ZENA = 'img/izveduvaci/931.jpg';
        const GRADSKE_CURE = 'img/izveduvaci/932.jpg';
        const KAKVA_NOC = 'img/izveduvaci/933.jpg';
        const DOBRE_DEVOJKE = 'img/izveduvaci/934.jpg';
        const JOS_TE_VOLIM = 'img/izveduvaci/935.jpg';
        const BALKANSKA_ULICA = 'img/izveduvaci/936.jpg';
        const KAKO_SAM_TE_VOLJELA = 'img/izveduvaci/937.jpg';
        const STO_SAM_JA_STO_SI_TI = 'img/izveduvaci/938.jpg';
        const RANO = 'img/izveduvaci/939.jpg';
        const ROCK_ME = 'img/izveduvaci/940.jpg';
        const KUCA_PORED_MORA = 'img/izveduvaci/941.jpg';
        const PJEVALI_SMO_PJESME_STARE = 'img/izveduvaci/942.jpg';
        const POZOVI_ME = 'img/izveduvaci/943.jpg';
        const IBRO_DIRKA = 'img/izveduvaci/944.jpg';
        const MENI_MAMA_NE_DA = 'img/izveduvaci/945.jpg';
        const RADOSTAN_DAN = 'img/izveduvaci/946.jpg';
        const MOZDA_MOZDA = 'img/izveduvaci/947.jpg';
        const LJUBAV_NIJE_ZA_NAS = 'img/izveduvaci/948.jpg';
        const JEDAN_COVEK_JEDNA_ZENA = 'img/izveduvaci/949.jpg';
        const GALEBOVI = 'img/izveduvaci/950.jpg';
        const JELENA = 'img/izveduvaci/951.jpg';
        const GLASNO_GLASNIJE = 'img/izveduvaci/952.jpg';
        const OD_SPLITA_DO_BEOGRADA_FT_DINO_DVORNIK = 'img/izveduvaci/953.jpg';
        const PISMO = 'img/izveduvaci/954.jpg';
        const DALMATINKA = 'img/izveduvaci/955.jpg';
        const KAZU_MI_DA_SI_JOS_UVEK_SAMA = 'img/izveduvaci/956.jpg';
        const PARISKI_LOKAL = 'img/izveduvaci/957.jpg';
        const AJSA = 'img/izveduvaci/958.jpg';
        const ELIZABET = 'img/izveduvaci/959.jpg';
        const CUVAJ_SE = 'img/izveduvaci/960.jpg';
        const JUBI_SAN_VASU_KCER = 'img/izveduvaci/961.jpg';
        const PROLJECE_BEZ_TEBE1 = 'img/izveduvaci/962.jpg';
        const JEDNU_MLADOST_IMAM = 'img/izveduvaci/963.jpg';
        const HARMONIKA = 'img/izveduvaci/964.jpg';
        const JUGOSLOVENKA = 'img/izveduvaci/965.jpg';
        const RUSKA_COKOLADA = 'img/izveduvaci/966.jpg';
        const JEDINO_MOJE = 'img/izveduvaci/967.jpg';
        const DOK_GITARA_SVIRA = 'img/izveduvaci/968.jpg';
        const DADO_TOPIC = 'img/izveduvaci/361.jpg';
        const TONY_MONTANO = 'img/izveduvaci/833.jpg';
        const VIKTORIJA = 'img/izveduvaci/877.jpg';
        const OLIVER_MANDIC = 'img/izveduvaci/591.jpg';
        const ZELJKO_BEBEK = 'img/izveduvaci/925.jpg';

        
        
        if (artist == 'FRATELLO') {var urlCoverArt = FRATELLO;}
            else if (artist == 'ZELJKO BEBEK') {var urlCoverArt = ZELJKO_BEBEK;}
            else if (artist == 'OLIVER MANDIC') {var urlCoverArt = OLIVER_MANDIC;}
            else if (artist == 'VIKTORIJA') {var urlCoverArt = VIKTORIJA;}
            else if (artist == 'TONY MONTANO') {var urlCoverArt = TONY_MONTANO;}
            else if (artist == 'DADO TOPIC') {var urlCoverArt = DADO_TOPIC;}
            else if (artist == 'STAVI PRAVU STVAR') {var urlCoverArt = STAVI_PRAVU_STVAR;}
            else if (artist == 'STO SI U KAVU STAVILA') {var urlCoverArt = STO_SI_U_KAVU_STAVILA;}
            else if (artist == 'OBICNA LJUBAVNA PJESMA') {var urlCoverArt = OBICNA_LJUBAVNA_PJESMA;}
            else if (artist == 'A STA DA RADIM') {var urlCoverArt = A_STA_DA_RADIM;}
            else if (artist == 'DIGNI ME VISOKO') {var urlCoverArt = DIGNI_ME_VISOKO;}
            else if (artist == 'OTKAZAN LET') {var urlCoverArt = OTKAZAN_LET;}
            else if (artist == 'LJUBAV PREKO ZIVE') {var urlCoverArt = LJUBAV_PREKO_ZICE;}
            else if (artist == 'MIKI MIKI') {var urlCoverArt = MIKI_MIKI;}
            else if (artist == 'DAO SAM TI DUSI') {var urlCoverArt = DAO_SAM_TI_DUSU;}
            else if (artist == 'S TOBOM NASAO SAM SRECU') {var urlCoverArt = S_TOBOM_NASAO_SAM_SRECU;}
            else if (artist == 'KESTENI') {var urlCoverArt = KESTENI;}
            else if (artist == 'POSLE 9 GODINA') {var urlCoverArt = POSLE_9_GODINA;}
            else if (artist == 'SANJA') {var urlCoverArt = SANJA;}
            else if (artist == 'EJ STA MI RADIS') {var urlCoverArt = EJ_STA_MI_RADIS;}
            else if (artist == 'NEK TI JUTRO MIRISE NA MENE') {var urlCoverArt = NEK_TI_JUTRO_MIRISE_NA_MENE;}
            else if (artist == 'DOJDJI U 5 DO 5') {var urlCoverArt = DOJDJI_U_5_DO_5;}
            else if (artist == 'ZEMLJO MOJA FT ISMETA KRAVAC') {var urlCoverArt = ZEMLJO_MOJA_FT_ISMETA_KRAVAC;}
            else if (artist == 'ANDJELI NAS ZOVU DA IM SKINEMO KRILA') {var urlCoverArt = ANDJELI_NAS_ZOVU_DA_IM_SKINEMO_KRILA;}
            else if (artist == 'O MLADOSTI') {var urlCoverArt = O_MLADOSTI;}
            else if (artist == 'SVE STO ZNAS O MENI') {var urlCoverArt = SVE_STO_ZNAS_O_MENI;}
            else if (artist == 'DEVOJKA IZ MOGA KRAJA') {var urlCoverArt = DEVOJKA_IZ_MOGA_KRAJA;}
            else if (artist == 'PROLJECE BEZ TEBE') {var urlCoverArt = PROLJECE_BEZ_TEBE;}
            else if (artist == 'ZAGRLI ME') {var urlCoverArt = ZAGRLI_ME;}
            else if (artist == 'DEVOJKA BROJ 8') {var urlCoverArt = DEVOJKA_BROJ_8;}
            else if (artist == 'PAKLENI VOZACI') {var urlCoverArt = PAKLENI_VOZACI;}
            else if (artist == 'ZA LJUBAV TREBA IMAT DUSU') {var urlCoverArt = ZA_LJUBAV_TREBA_IMAT_DUSU;}
            else if (artist == 'VOLJELA ME NIJE NI JEDNA') {var urlCoverArt = VOLJELA_ME_NIJE_NI_JEDNA;}
            else if (artist == 'USNE VRELE VISNJE') {var urlCoverArt = USNE_VRELE_VISNJE;}
            else if (artist == 'AKO ZNAS BILO STA') {var urlCoverArt = AKO_ZNAS_BILO_STA;}
            else if (artist == 'BALKAN') {var urlCoverArt = BALKAN;}
            else if (artist == 'GRACIJA') {var urlCoverArt = GRACIJA;}
            else if (artist == 'MARINA') {var urlCoverArt = MARINA;}
            else if (artist == 'LJEPE ZENE PROLAZE KROZ GRAD') {var urlCoverArt = LJEPE_ZENE_PROLAZE_KROZ_GRAD;}
            else if (artist == 'NOC BEZ SNA') {var urlCoverArt = NOC_BEZ_SNA;}
            else if (artist == 'DA TE VIDIM GOLU') {var urlCoverArt = DA_TE_VIDIM_GOLU;}
            else if (artist == 'SAMO NAM JE LJUBAV POTREBNA') {var urlCoverArt = SAMO_NAM_JE_LJUBAV_POTREBNA;}
            else if (artist == 'PLAVI SAFIRU') {var urlCoverArt = PLAVI_SAFIRU;}
            else if (artist == 'OD KADe TEBE VOLIM') {var urlCoverArt = OD_KAD_TEBE_VOLIM;}
            else if (artist == 'VERUJEM NE VERUJEM') {var urlCoverArt = VERUJEM_NE_VERUJEM;}
            else if (artist == 'GODINE PROLAZE') {var urlCoverArt = GODINE_PROLAZE;}
            else if (artist == 'TISINA') {var urlCoverArt = TISINA;}
            else if (artist == 'RUSKI VOZ') {var urlCoverArt = RUSKI_VOZ;}
            else if (artist == 'VESELA PESMA') {var urlCoverArt = VESELA_PESMA;}
            else if (artist == 'ZIVOT JE NEKAD SIV NEKAD ZUT') {var urlCoverArt = ZIVOT_JE_NEKAD_SIV_NEKAD_ZUT;}
            else if (artist == 'GORE DOLE') {var urlCoverArt = GORE_DOLE;}
            else if (artist == 'TI SE LJUBIS') {var urlCoverArt = TI_SE_LJUBIS;}
            else if (artist == 'SA DRUGE STRANE') {var urlCoverArt = SA_DRUGE_STRANE;}
            else if (artist == 'ZAZMURI') {var urlCoverArt = ZAZMURI;}
            else if (artist == 'DO BEOGRADA') {var urlCoverArt = DO_BEOGRADA;}
            else if (artist == 'VIDI STA SAM TI URADIO OD PESME MAMA') {var urlCoverArt = VIDI_STA_SAM_TI_URADIO_OD_PESME_MAMA;}
            else if (artist == 'SARENE PILULE') {var urlCoverArt = SARENE_PILULE;}
            else if (artist == 'VEK') {var urlCoverArt = VEK;}
            else if (artist == 'TAMARA') {var urlCoverArt = TAMARA;}
            else if (artist == 'POLJUBI ME') {var urlCoverArt = POLJUBI_ME;}
            else if (artist == 'LEPA JANJA RIBERAVA KCI') {var urlCoverArt = LEPA_JANJA_RIBAREVA_KCI;}
            else if (artist == 'ZMAJ OD NOVAJA') {var urlCoverArt = ZMAJ_OD_NOCAJA;}
            else if (artist == 'MUZIKA NA STRUJU') {var urlCoverArt = MUZIKA_NA_STRUJU;}
            else if (artist == 'OVO JE BALKAN') {var urlCoverArt = OVO_JE_BALKAN;}
            else if (artist == 'JOS TE VOLIM') {var urlCoverArt = JOS_TE_VOLIM;}
            else if (artist == 'NA VRHOVIMA PRSTIJU') {var urlCoverArt = NA_VRHOVIMA_PRSTIJU;}
            else if (artist == 'KAD HODAS') {var urlCoverArt = KAD_HODAS;}
            else if (artist == 'MOJI SU DRUGOVI') {var urlCoverArt = MOJI_SU_DRUGOVI}
            else if (artist == 'GDE SI') {var urlCoverArt = GDE_SI;}
            else if (artist == 'BAM BAM BAM') {var urlCoverArt = BAM_BAM_BAM;}
            else if (artist == 'NEKA SVEMIR CUJE NEMIR') {var urlCoverArt = NEKA_SVEMIR_CUJE_NEMIR;}
            else if (artist == 'JEDINO TO SE ZOVE LJUBAV') {var urlCoverArt = JEDINO_TO_SE_ZOVE_LJUBAV;}
            else if (artist == 'KRV SRECA SUZI I ZNOJ') {var urlCoverArt = KRV_SRECA_SUZE_I_ZNOJ;}
            else if (artist == 'RUDI') {var urlCoverArt = RUDI;}
            else if (artist == 'BRAZIL') {var urlCoverArt = BRA_ZIL;}
            else if (artist == 'HAJDE DA UZMEMO NEKI DOBAR AUTO') {var urlCoverArt = HAJDE_DA_UZMEMO_NEKI_DOBAR_AUTO;}
            else if (artist == 'BADEMI I SO FT BAJAGA') {var urlCoverArt = BADEMI_I_SO_FT_BAJAGA;}
            else if (artist == 'DA PRICAMO O LJUBAVU') {var urlCoverArt = DA_PRICAMO_O_LJUBAVI;}
            else if (artist == 'IPAK POZELIM NEKO PISMO') {var urlCoverArt = IPAK_POZELIM_NEKO_PISMO;}
            else if (artist == 'BITANGA I PRINCEZA') {var urlCoverArt = BITANGA_I_PRINCEZA;}
            else if (artist == 'SVE CE TO MILA MOJA PREKRTITI RUZMARIN') {var urlCoverArt = SVE_CE_TO_MILA_MOJA_PREKRITI_RUZMARIN;}
            else if (artist == 'NOCAS JE KO LUBENICA') {var urlCoverArt = NOCAS_JE_KO_LUBENICA;}
            else if (artist == 'PLJUNI I ZAPEVAJ MOJA JUGOSLAVIJO') {var urlCoverArt = PLJUNI_I_ZAPEVAJ_MOJA_JUGOSLAVIJO;}
            else if (artist == 'A I TI ME IZNEVJERI') {var urlCoverArt = A_I_TI_ME_IZNEVJERI;}
            else if (artist == 'RUZICA SI BILA') {var urlCoverArt = RUZICA_SI_BILA;}
            else if (artist == 'HAJDEMO U PLANINE') {var urlCoverArt = HAJDEMO_U_PLANINE;}
            else if (artist == 'JER KAD OSTARIS') {var urlCoverArt = JER_KAD_OSTARIS;}
            else if (artist == 'LAZES ZLATO') {var urlCoverArt = LAZES_ZLATO;}
            else if (artist == 'ZA ESMU') {var urlCoverArt = ZA_ESMU;}
            else if (artist == 'LIPE CVATU') {var urlCoverArt = LIPE_CVATU;}
            else if (artist == 'PADAJU ZVEZDE') {var urlCoverArt = PADAJU_ZVEZDE;}
            else if (artist == 'DA TE BOFDO NEVOLIM') {var urlCoverArt = DA_TE_BOGDO_NEVOLIM;}
            else if (artist == 'MENI SE NESPAVA') {var urlCoverArt = MENI_SE_NESPAVA;}
            else if (artist == 'AKO MOZES ZABORAVI') {var urlCoverArt = AKO_MOZES_ZABORAVI;}
            else if (artist == 'U VREME OTKAZANIH LETOVA') {var urlCoverArt = U_VREME_OTKAZANIH_LETOVA;}
            else if (artist == 'DOZIVJETI STOTU') {var urlCoverArt = DOZIVJETI_STOTU;}
            else if (artist == 'ZAZMURI I BROJ DO 100') {var urlCoverArt = ZAZMURI_I_BROJ_DO_100;}
            else if (artist == 'PRISTAO SAM BICU SVE STO HOCE') {var urlCoverArt = PRISTAO_SAM_BICU_SVE_STO_HOCE;}
            else if (artist == 'HA HA HA SVI MARS NA PLJES') {var urlCoverArt = HA_HA_HA_SVI_MARS_NA_PLJES;}
            else if (artist == 'KAD BI BIO BIJELO DUGME') {var urlCoverArt = KAD_BI_BIO_BIJELO_DUGME;}
            else if (artist == 'SELMA') {var urlCoverArt = SELMA;}
            else if (artist == 'IMA NEKA TAJNA VEZA') {var urlCoverArt = IMA_NEKA_TAJNA_VEZA;}
            else if (artist == 'DA SAM PEKAR') {var urlCoverArt = DA_SAM_PEKAR;}
            else if (artist == 'NE SPAVAJ MALA MOJA MUZIKA DOK SVIRA') {var urlCoverArt = NE_SPAVAJ_MALA_MOJA_MUZIKA_DOK_SVIRA;}
            else if (artist == 'AKO IMA BOGA') {var urlCoverArt = AKO_IMA_BOGA;}
            else if (artist == 'NAPILE SE ULICE') {var urlCoverArt = NAPILE_SE_ULICE;}
            else if (artist == 'STA IMA NOVO') {var urlCoverArt = STA_IMA_NOVO;}
            else if (artist == 'NAKON SVIH OVIH GODINA') {var urlCoverArt = NAKON_SVIH_OVIH_GODINA;}
            else if (artist == 'CIRIBIRIBELA') {var urlCoverArt = CIRIBIRIBELA;}
            else if (artist == 'DJURDJEVDAN') {var urlCoverArt = DJURDJEVDAN;}
            else if (artist == 'EVO ZAKLECU SE') {var urlCoverArt = EVO_ZAKLECU_SE;}
            else if (artist == 'IZGLEDALA JE MALO CUDNO U KAPUTU') {var urlCoverArt = IZGLEDALA_JE_MALO_CUDNO_U_KAPUTU;}
            else if (artist == 'LOSE VINO') {var urlCoverArt = LOSE_VINO;}
            else if (artist == 'SANJAO SAM NOCAS DA TE NEMAM') {var urlCoverArt = SANJAO_SAM_NOCAS_DA_TE_NEMAM;}
            else if (artist == 'NA ZADNJEM SEDISTU MOGA AUTA') {var urlCoverArt = NA_ZADNJEM_SEDISTU_MOGA_AUTA;}
            else if (artist == 'SVI MARS NA PLES') {var urlCoverArt = SVI_MARS_NA_PLES;}
            else if (artist == 'TAKO TI JE MALA MOJA') {var urlCoverArt = TAKO_TI_JE_MALA_MOJA;}
            else if (artist == 'DOBRO VAM JUTRO') {var urlCoverArt = DOBRO_VAM_JUTRO;}
            else if (artist == 'ZLATNI DAN') {var urlCoverArt = ZLATNI_DAN;}
            else if (artist == 'MILO MOJE') {var urlCoverArt = MILO_MOJE;}
            else if (artist == 'UZALUD ME PODSECAS') {var urlCoverArt = UZALUD_ME_PODSECAS;}
            else if (artist == 'STO JE SA PRINCEZOM MOJE VRELE MLADOSTI') {var urlCoverArt = STO_JE_SA_PRINCEZOM_MOJE_VRELE_MLADOSTI;}
            else if (artist == 'KO SAM BEZ TEBE') {var urlCoverArt = KO_SAM_BEZ_TEBE;}
            else if (artist == 'EMILY') {var urlCoverArt = EMILY;}
            else if (artist == 'KUDA IDU IZGUBLJENE DEVOJKE') {var urlCoverArt = KUDA_IDU_IZGUBLJENE_DEVOJKE;}
            else if (artist == 'PRODALA ME TI') {var urlCoverArt = PRODALA_ME_TI;}
            else if (artist == 'DOK SVIRA RADIO') {var urlCoverArt = DOK_SVIRA_RADIO;}
            else if (artist == 'DALEKO FT KEMALMONTENO') {var urlCoverArt = DALEKO_FT_KEMALMONTENO;}
            else if (artist == 'MI SMO JACI I OD SUDBINE') {var urlCoverArt = MI_SMO_JACI_I_OD_SUDBINE;}
            else if (artist == 'U DOBRU I ZLU') {var urlCoverArt = U_DOBRU_I_ZLU;}
            else if (artist == 'ELOIS') {var urlCoverArt = ELOIS;}
            else if (artist == 'TUGA TI I JA') {var urlCoverArt = TUGA_TI_I_JA;}
            else if (artist == 'TO MI RADI') {var urlCoverArt = TO_MI_RADI;}
            else if (artist == 'NEKAKO S PROLJECA FT KEMAL MONTENO') {var urlCoverArt = NEKAKO_S_PROLJECA_FT_KEMAL_MONTENO;}
            else if (artist == 'MOJE NEJMILIJE') {var urlCoverArt = MOJE_NAJMILIJE;}
            else if (artist == 'TUGO NESRECO') {var urlCoverArt = TUGO_NESRECO;}
            else if (artist == 'ZOVU NAS ULICE') {var urlCoverArt = ZOVU_NAS_ULICE;}
            else if (artist == 'BJEZI KISO S PROZORA') {var urlCoverArt = BJEZI_KISO_S_PROZORA;}
            else if (artist == 'TAMO GDE LJUBAV POCINJE') {var urlCoverArt = TAMO_GDE_LJUBAV_POCINJE;}
            else if (artist == 'TVOGA SRCA VRATA') {var urlCoverArt = TVOGA_SRCA_VRATA;}
            else if (artist == 'DIRLIJA') {var urlCoverArt = DIRLIJA;}
            else if (artist == 'IMAM NEKE FORE') {var urlCoverArt = IMAM_NEKE_FORE;}
            else if (artist == 'VOLIO BI DA SI TU') {var urlCoverArt = VOLIO_BI_DA_SI_TU;}
            else if (artist == 'SAMPANJSKI POLJUBAC') {var urlCoverArt = SAMPANJSKI_POLJUBAC;}
            else if (artist == 'DA MI JE DO NJE') {var urlCoverArt = DA_MI_JE_DO_NJE;}
            else if (artist == 'STIZU ME SECANJA') {var urlCoverArt = STIZU_ME_SECANJA;}
            else if (artist == 'IMA NESTO OD SRCA DO SRCA') {var urlCoverArt = IMA_NESTO_OD_SRCA_DO_SRCA;}
            else if (artist == 'AKO AKO') {var urlCoverArt = AKO_AKO;}
            else if (artist == 'SVIDJA MI SE OVA STVAR') {var urlCoverArt = SVIDJA_MI_SE_OVA_STVAR;}
            else if (artist == 'PRINCIPESSA') {var urlCoverArt = PRINCIPESSA;}
            else if (artist == 'NEMA VISE VREMENA') {var urlCoverArt = NEMA_VISE_VREMENA;}
            else if (artist == 'S TVOJIH USANA') {var urlCoverArt = S_TVOJIH_USANA;}
            else if (artist == 'FLOYD') {var urlCoverArt = FLOYD;}
            else if (artist == 'JA HOCU ZIVOT') {var urlCoverArt = JA_HOCU_ZIVOT;}
            else if (artist == 'NOC JE PREKRASNA') {var urlCoverArt = NOC_JE_PREKRASNA;}
            else if (artist == 'DZULI') {var urlCoverArt = DZULI;}
            else if (artist == 'NEKA MI NE SVANE') {var urlCoverArt = NEKA_MI_NE_SVANE;}
            else if (artist == 'DA JE SALDJE ZASPATI') {var urlCoverArt = DA_JE_SALDJE_ZASPATI;}
            else if (artist == 'ULICA JORGOVANA') {var urlCoverArt = ULICA_JORGOVANA;}
            else if (artist == 'JA BIH DA PEVAM') {var urlCoverArt = JA_BIH_DA_PEVAM;}
            else if (artist == 'JULIJA') {var urlCoverArt = JULIJA;}
            else if (artist == 'LETNJE KISE') {var urlCoverArt = LETNJE_KISE;}
            else if (artist == 'OAZA SNOVA') {var urlCoverArt = OAZA_SNOVA;}
            else if (artist == 'SOBA 23') {var urlCoverArt = SOBA_23;}
            else if (artist == 'PROGRAM TVOG KOMPJUTERA') {var urlCoverArt = PROGRAM_TVOG_KOMPJUTERA;}
            else if (artist == 'VOLI ME JOS OVU NOC') {var urlCoverArt = VOLI_ME_JOS_OVU_NOC;}
            else if (artist == 'JA SAM LAZLJIVA') {var urlCoverArt = JA_SAM_LAZLJIVA;}
            else if (artist == 'U RITMU ME OKRENI') {var urlCoverArt = U_RITMU_ME_OKRENI;}
            else if (artist == 'TI SI MI U MISLIMA') {var urlCoverArt = TI_SI_MI_U_MISLIMA;}
            else if (artist == 'TEBI PRIPADAM') {var urlCoverArt = TEBI_PRIPADAM;}
            else if (artist == 'LJUBAV SE ZOVE IMENOM TVOIM') {var urlCoverArt = LJUBAV_SE_ZOVE_IMENOM_TVOIM;}
            else if (artist == 'NECU DA ZNAM ZA NIKOG OSIM TEBE') {var urlCoverArt = NECU_DA_ZNAM_ZA_NIKOG_OSIM_TEBE;}
            else if (artist == 'JACE MANIJACE') {var urlCoverArt = JACE_MANIJACE;}
            else if (artist == 'UMRI PRIJE SMRTI') {var urlCoverArt = UMRI_PRIJE_SMRTI;}
            else if (artist == 'SREDINOM') {var urlCoverArt = SREDINOM;}
            else if (artist == 'MOJ JE ZIVOT SVICARSKA') {var urlCoverArt = MOJ_JE_ZIVOT_SVICARSKA;}
            else if (artist == 'SVE JE LAZ') {var urlCoverArt = SVE_JE_LAZ;}
            else if (artist == 'GODINAMA') {var urlCoverArt = GODINAMA;}
            else if (artist == 'KAD SI REKLA DA ME VOLIS') {var urlCoverArt = KAD_SI_REKLA_DA_ME_VOLIS;}
            else if (artist == 'HITNA') {var urlCoverArt = HITNA;}
            else if (artist == 'DA JE TUGA SNIJEG') {var urlCoverArt = DA_JE_TUGA_SNIJEG;}
            else if (artist == 'KREMEN') {var urlCoverArt = KREMEN;}
            else if (artist == 'KAD COVIJEK VOLI ZENU') {var urlCoverArt = KAD_COVIJEK_VOLI_ZENU;}
            else if (artist == 'STA TI ZNACIM JA') {var urlCoverArt = STA_TI_ZNACIM_JA;}
            else if (artist == 'DANAS SAM OK') {var urlCoverArt = DANAS_SAM_OK;}
            else if (artist == 'BOSNOM BEHAR PROBEHARO') {var urlCoverArt = BOSNOM_BEHAR_PROBEHARAO;}
            else if (artist == 'OBICNA LJUBAVNA PJESMA') {var urlCoverArt = OBICNA_LJUBAVNAPJESMA;}
            else if (artist == 'A STA DA RADIM') {var urlCoverArt = ASTA_DA_RADIM;}
            else if (artist == 'DIGNI ME VISOKO') {var urlCoverArt = DIGNI_MEVISOKO;}
            else if (artist == 'FRATELLO') {var urlCoverArt = FRAT_ELLO;}
            else if (artist == 'STAVI PRAVU STVAR') {var urlCoverArt = STAVI_PRAVUSTVAR;}
            else if (artist == 'STA SI MI U KAVU STAVILA') {var urlCoverArt = STA_SI_MI_UKAVU_STAVILA;}
            else if (artist == 'NESTO LIJEPO TREBA DA SE DESI') {var urlCoverArt = NESTO_LIJEPO_TREBA_DA_SE_DESI;}
            else if (artist == 'MJESECINA') {var urlCoverArt = MJESECINA;}
            else if (artist == 'JEL SARAJEVO GDE JE NEKAD BILO') {var urlCoverArt = JEL_SARAJEVO_GDE_JE_NEKAD_BILO;}
            else if (artist == 'KAD ZAMIRISU JORGOVANI FT VESNA ZMIJANAC') {var urlCoverArt = KADZAMIRISUJORGOVANIFTVESNA_ZMIJANAC;}
            else if (artist == 'ZAR JE TO SVE STO IMAM OD TEBE') {var urlCoverArt = ZAR_JE_TO_SVE_STO_IMAM_OD_TEBE;}
            else if (artist == 'JA POTPUNO TRIJEZAN UMIREM') {var urlCoverArt = JA_POTPUNO_TRIJEZAN_UMIREM;}
            else if (artist == 'NE ZOVI ME NA GRIJEH') {var urlCoverArt = NE_ZOVI_ME_NA_GRIJEH;}
            else if (artist == 'NEMA JA 18 GODINA') {var urlCoverArt = NEMAM_JA_18_GODINA;}
            else if (artist == 'KOKUZNA VREMENA') {var urlCoverArt = KOKUZNA_VREMENA;}
            else if (artist == 'JA SAM NA TE NAVIKO') {var urlCoverArt = JA_SAM_NA_TE_NAVIKO;}
            else if (artist == 'UCINI MI PRAVU STVAR') {var urlCoverArt = UCINI_MI_PRAVU_STVAR;}
            else if (artist == 'SA MOJIH USANA') {var urlCoverArt = SA_MOJIH_USANA;}
            else if (artist == 'DA SUTIS') {var urlCoverArt = DA_SUTIS;}
            else if (artist == 'OTKRIT CU TI TAJNU') {var urlCoverArt = OTKRIT_CU_TI_TAJNU;}
            else if (artist == 'DESET MLADJA') {var urlCoverArt = DESET_MLADJA;}
            else if (artist == 'OSTAT CE ISTINE DVIJE') {var urlCoverArt = OSTAT_CE_ISTINE_DVIJE;}
            else if (artist == 'AKO ME IKAD SRETNES') {var urlCoverArt = AKO_ME_IKADA_SRETNES;}
            else if (artist == 'ZABORAVI') {var urlCoverArt = ZABORAVI;}
            else if (artist == 'MOJA BOGDA SNA') {var urlCoverArt = MOJA_BOGDA_SNA;}
            else if (artist == 'BASKA TI') {var urlCoverArt = BASKA_TI;}
            else if (artist == 'SMIJEHOM STAH POKRIJEM') {var urlCoverArt = SMIJEHOM_STRAH_POKRIJEM;}
            else if (artist == 'NEK PADAJU CUSKIJE') {var urlCoverArt = NEK_PADAJU_CUSKIJE;}
            else if (artist == 'ISPOCETKA') {var urlCoverArt = ISPOCETKA;}
            else if (artist == 'SVE DOK TE BUDE IMALO') {var urlCoverArt = SVE_DOK_TE_BUDE_IMALO;}
            else if (artist == 'LAZU ME') {var urlCoverArt = LAZU_ME;}
            else if (artist == 'LELO') {var urlCoverArt = LELO;}
            else if (artist == 'MARIJA') {var urlCoverArt = MARIJA;}
            else if (artist == 'KAKO SI TOPLA I MILA') {var urlCoverArt = KAKO_SI_TOPLA_I_MILA;}
            else if (artist == 'KRIVO JE MORE') {var urlCoverArt = KRIVO_JE_MORE;}
            else if (artist == 'JEDINA MOJA') {var urlCoverArt = JEDINA_MOJA;}
            else if (artist == 'ZAUVJEK TVOJ') {var urlCoverArt = ZAUVJEK_TVOJ;}
            else if (artist == 'VOL TE TVOJA ZVER') {var urlCoverArt = VOLI_TE_TVOJA_ZVER;}
            else if (artist == 'OSTAVI UZ MENE') {var urlCoverArt = OSTANI_UZ_MENE;}
            else if (artist == 'BAMBINA') {var urlCoverArt = BAMBINA;}
            else if (artist == 'DANI LJUBAVI') {var urlCoverArt = DANI_LJUBAVI;}
            else if (artist == 'IVONA') {var urlCoverArt = IVONA;}
            else if (artist == 'JAGODE I COKOLADA') {var urlCoverArt = JAGODE_I_COKOLADA;}
            else if (artist == 'PRICAJ MI O LJUBAVI') {var urlCoverArt = PRICAJ_MI_O_LJUBAVI;}
            else if (artist == 'ANDJELA MOJA JE DRAGA VESTICA') {var urlCoverArt = ANDJELA_MOJA_JE_DRAGA_VESTICA;}
            else if (artist == 'BOZA ZVANI PUB') {var urlCoverArt = BOZA_ZVANI_PUB;}
            else if (artist == 'DEVOJKA SA CARDAS NOGAMA') {var urlCoverArt = DEVOJKA_SA_CARDAS_NOGAMA;}
            else if (artist == 'DIVLJI BADEM') {var urlCoverArt = DIVLJI_BADEM;}
            else if (artist == 'D MOLL') {var urlCoverArt = D_MOLL;}
            else if (artist == 'JA LUZER') {var urlCoverArt = JA_LUZER;}
            else if (artist == 'JAROSLOAVA PRINCEZO JAVI SE') {var urlCoverArt = JAROSLAVA_PRINCEZO_JAVI_SE;}
            else if (artist == 'LEPA PROTINA KCI') {var urlCoverArt = LEPA_PROTINA_KCI;}
            else if (artist == 'LJERKA') {var urlCoverArt = LJERKA;}
            else if (artist == 'NE LOMITE MI BAGRENJE') {var urlCoverArt = NE_LOMITE_MI_BAGRENJE;}
            else if (artist == 'NE VOLIM JANUAR') {var urlCoverArt = NE_VOLIM_JANUAR;}
            else if (artist == 'NEKI NOVI KLINCI') {var urlCoverArt = NEKI_NOVI_KLINCI;}
            else if (artist == 'NEVERNIK') {var urlCoverArt = NEVERNIK;}
            else if (artist == 'NIKAD KAO BANE') {var urlCoverArt = NIKAD_KAO_BANE;}
            else if (artist == 'OLELOLE') {var urlCoverArt = OLELOLE;}
            else if (artist == 'OPROSTI MI KARTIN') {var urlCoverArt = OPROSTI_MI_KATRIN;}
            else if (artist == 'PA DOBRO GDE SI TI') {var urlCoverArt = PA_DOBRO_GDE_SI_TI;}
            else if (artist == 'PORTRET MOG ZIVOTA') {var urlCoverArt = PORTRET_MOG_ZIVOTA;}
            else if (artist == 'PROVINCIJALKA') {var urlCoverArt = PROVINCIJALKA;}
            else if (artist == 'PRVA LJUBAV') {var urlCoverArt = PRVA_LJUBAV;}
            else if (artist == 'RINGISPIL') {var urlCoverArt = RINGISPIL;}
            else if (artist == 'SIN JEDINAC') {var urlCoverArt = SIN_JEDINAC;}
            else if (artist == 'SLABO DIVANIM MADZARSKI') {var urlCoverArt = SLABO_DIVANIM_MADZARSKI;}
            else if (artist == 'SLOVENSKA') {var urlCoverArt = SLOVENSKA;}
            else if (artist == 'SVIRAJTE MI JESEN STIZE DUNJO MOJA') {var urlCoverArt = SVIRAJTE_MI_JESEN_STIZE_DUNJO_MOJA;}
            else if (artist == 'USPAVANKA ZA DECAKA') {var urlCoverArt = USPAVANKA_ZA_DECAKA;}
            else if (artist == 'OLIVERA') {var urlCoverArt = OLIVERA;}
            else if (artist == 'SJAJ U TAMI') {var urlCoverArt = SJAJ_U_TAMI;}
            else if (artist == 'SAKOM O STOL') {var urlCoverArt = SAKOM_O_STOL;}
            else if (artist == 'JA NOCAS UMIREM') {var urlCoverArt = JA_NOCAS_UMIREM;}
            else if (artist == 'KRIVI LJUDI') {var urlCoverArt = KRIVI_LJUDI;}
            else if (artist == 'MALO MI ZA SRICU TRIBA') {var urlCoverArt = MALO_MI_ZA_SRICU_TRIBA;}
            else if (artist == 'MARIJA MAGDALENA') {var urlCoverArt = MARIJA_MAGDALENA;}
            else if (artist == 'MORAM') {var urlCoverArt = MORAM;}
            else if (artist == 'PETAK') {var urlCoverArt = PETAK;}
            else if (artist == 'TO') {var urlCoverArt = TO;}
            else if (artist == 'ZELJO MOJA') {var urlCoverArt = ZELJO_MOJA;}
            else if (artist == 'NI DA MORA NESTANE') {var urlCoverArt = NI_DA_MORA_NESTANE;}
            else if (artist == 'STAJE OD MENE OSTALO') {var urlCoverArt = STAJE_OD_MENE_OSTALO;}
            else if (artist == 'IMA LI NADE ZA NAS FT ANDJELA ZECIC') {var urlCoverArt = IMA_LI_NADE_ZA_NAS_FT_ANDJELA_ZECIC;}
            else if (artist == 'PISI MI') {var urlCoverArt = PISI_MI;}
            else if (artist == 'PRODJE OVAJ DAN') {var urlCoverArt = PRODJE_OVAJ_DAN;}
            else if (artist == 'PAR GODINA ZA NAS') {var urlCoverArt = PAR_GODINA_ZA_NAS;}
            else if (artist == 'SRCE') {var urlCoverArt = SRCE;}
            else if (artist == 'OCI BOJE MEDA') {var urlCoverArt = OCI_BOJE_MEDA;}
            else if (artist == 'TI SI SAM MOJ BOL') {var urlCoverArt = TI_SI_SAV_MOJ_BOL;}
            else if (artist == 'KURG') {var urlCoverArt = KRUG;}
            else if (artist == 'DA SI TAKO JAKA') {var urlCoverArt = DA_SI_TAKO_JAKA;}
            else if (artist == 'BEJBE TI NISI TU') {var urlCoverArt = BEJBE_TI_NISI_TU;}
            else if (artist == 'IGRA ROCK NN ROLL CELA JUGOSLAVIJA') {var urlCoverArt = IGRA_ROCK_NN_ROLL_CELA_JUGOSLAVIJA;}
            else if (artist == 'MALA MALA MALA GRUPA PEDERA') {var urlCoverArt = MALA_MALA_MALA_GRUPA_PEDERA;}
            else if (artist == 'PARANOJA') {var urlCoverArt = PARANOJA;}
            else if (artist == 'STO JA VOLIM TAJ SEX') {var urlCoverArt = STO_JA_VOLIM_TAJ_SEX;}
            else if (artist == 'A SADA IDEM FT TIFA') {var urlCoverArt = A_SADA_IDEM_FT_TIFA;}
            else if (artist == 'BOJE SU U NAMA') {var urlCoverArt = BOJE_SU_U_NAMA;}
            else if (artist == 'DOCI CU TI U SNOVIMA') {var urlCoverArt = DOCI_CU_TI_U_SNOVIMA;}
            else if (artist == 'LIJEPO LIJEPO NEOPISIVO') {var urlCoverArt = LIJEPO_LIJEPO_NEOPISIVO;}
            else if (artist == 'NJEZNO NJEZNO NJEZNIJE') {var urlCoverArt = NJEZNO_NJEZNO_NJEZNIJE;}
            else if (artist == 'PJEVAMO DO ZORE') {var urlCoverArt = PJEVAJMO_DO_ZORE;}
            else if (artist == 'ZAMISLI ZIVOT U RITMU MUZIKE ZA PLES') {var urlCoverArt = ZAMISLI_ZIVOT_U_RITMU_MUZIKE_ZA_PLES;}
            else if (artist == 'DOBRE VIBRACIJE') {var urlCoverArt = DOBRE_VIBRACIJE;}
            else if (artist == 'SRCE NA CESTI') {var urlCoverArt = SRCE_NA_CESTI;}
            else if (artist == 'MI NISMO SAMI') {var urlCoverArt = MI_NISMO_SAMI;}
            else if (artist == 'SJECAM SE PRVOG POLJUPCA') {var urlCoverArt = SJECAM_SE_PRVOG_POLJUPCA;}
            else if (artist == 'LJUBAV JE ZAKON') {var urlCoverArt = LJUBAV_JE_ZAKON;}
            else if (artist == 'MACKA') {var urlCoverArt = MACKA;}
            else if (artist == 'ZABORAVIT CU SVE') {var urlCoverArt = ZABORAVIT_CU_SVE;}
            else if (artist == 'ZVONI TELEFON') {var urlCoverArt = ZVONI_TELEFON;}
            else if (artist == 'VOLIM TE BUDALO MALA') {var urlCoverArt = VOLIM_TE_BUDALO_MALA;}
            else if (artist == 'ZAGRLJENI') {var urlCoverArt = ZAGRLJENI;}
            else if (artist == 'PAMTIM SAMO SRETNE DANE') {var urlCoverArt = PAMTIM_SAMO_SRETNE_DANE;}
            else if (artist == 'ON ME VOLI NA SVOJ NACIN') {var urlCoverArt = ON_ME_VOLI_NA_SVOJ_NACIN;}
            else if (artist == 'VINO I GITARE') {var urlCoverArt = VINO_I_GITARE;}
            else if (artist == 'CINIM PRAVU STVAR') {var urlCoverArt = CINIM_PRAVU_STVAR;}
            else if (artist == 'DVIJE DUSE') {var urlCoverArt = DVIJE_DUSE;}
            else if (artist == 'ISPOD MOGA PRAMCA') {var urlCoverArt = ISPOD_MOGA_PRAMCA;}
            else if (artist == 'OVO MI JE SKOLA') {var urlCoverArt = OVO_MI_JE_SKOLA;}
            else if (artist == 'SUVISE SAM NJEN') {var urlCoverArt = SUVISE_SAM_NJEN;}
            else if (artist == 'BAS TI LIJEPO STOJE SUZE') {var urlCoverArt = BAS_TI_LIJEPO_STOJE_SUZE;}
            else if (artist == 'HEJ KAKO SI') {var urlCoverArt = HEJ_KAKO_SI;}
            else if (artist == 'JAVI SE') {var urlCoverArt = JAVI_SE;}
            else if (artist == 'KAD DODJE OKTOBAR') {var urlCoverArt = KAD_DODJE_OKTOBAR;}
            else if (artist == 'KAO DOMINE') {var urlCoverArt = KAO_DOMINE;}
            else if (artist == 'COVAM NOC OD BUDNIH') {var urlCoverArt = CUVAM_NOC_OD_BUDNIH;}
            else if (artist == 'FEMME FATALE') {var urlCoverArt = FEMME_FATALE;}
            else if (artist == 'KAO KAKAO') {var urlCoverArt = KAO_KAKAO;}
            else if (artist == 'MAMURNI LJUDI') {var urlCoverArt = MAMURNI_LJUDI;}
            else if (artist == 'SKOPJE') {var urlCoverArt = SKOPJE;}
            else if (artist == 'UCI ME MAJKO KARAJ ME') {var urlCoverArt = UCI_ME_MAJKO_KARAJ_ME;}
            else if (artist == 'CUKNI VO DRVO') {var urlCoverArt = CUKNI_VO_DRVO;}
            else if (artist == 'IMA VREMENA') {var urlCoverArt = IMA_VREMENA;}
            else if (artist == 'SANJAO SAM MOJ RUZICU') {var urlCoverArt= SANJAO_SAM_MOJ_RUZICU;}
            else if (artist == 'GUTLJAJ VINA') {var urlCoverArt = GUTLJAJ_VINA;}
            else if (artist == 'JEL ZBOG NJE') {var urlCoverArt = JEL_ZBOG_NJE;}
            else if (artist == 'KOKOLO') {var urlCoverArt = KOKOLO;}
            else if (artist == 'LJUBE SE DOBRI LOSI ZLI') {var urlCoverArt = LJUBE_SE_DOBRI_LOSI_ZLI;}
            else if (artist == 'MINUT SRCA TVOG') {var urlCoverArt = MINUT_SRCA_TVOG;}
            else if (artist == 'OKO MOJE SANJIVO') {var urlCoverArt = OKO_MOJE_SANJIVO;}
            else if (artist == 'OPIJUM') {var urlCoverArt = OPIJUM;}
            else if (artist == 'PUT PUTUJEM') {var urlCoverArt = PUT_PUTUJEM;}
            else if (artist == 'RANO RANIJE') {var urlCoverArt = RANO_RANIJE;}
            else if (artist == 'SUZE BISERNE') {var urlCoverArt = SUZE_BISERNE;}
            else if (artist == 'SVE BI SEKE LJUBILE MORNAER') {var urlCoverArt = SVE_BI_SEKE_LJUBILE_MORNARE;}
            else if (artist == 'TAMARA') {var urlCoverArt = TAMARA1;}
            else if (artist == 'AKO ME OSTAVIS') {var urlCoverArt = AKO_ME_OSTAVIS;}
            else if (artist == 'JA NEMAM VISE RAZLOGA DA ZIVIM') {var urlCoverArt = JA_NEMAM_VISE_RAZLOGA_DA_ZIVIM;}
            else if (artist == 'JEDAN DAN ZIVOTA') {var urlCoverArt = JEDAN_DAN_ZIVOTA;}
            else if (artist == 'JOS I DANAS TEKU SUZE JEDNE ZENE') {var urlCoverArt = JOS_I_DANAS_TEKU_SUZE_JEDNE_ZENE;}
            else if (artist == 'MALO MI JE JEDAN ZIVOT S TOBOM') {var urlCoverArt = MALO_MI_JE_JEDAN_ZIVOT_S_TOBOM;}
            else if (artist == 'NIKOGA NISAM VOLIO TAKO') {var urlCoverArt = NIKOGA_NISAM_VOLIO_TAKO;}
            else if (artist == 'OSTALA SI UVIJEK ISTA') {var urlCoverArt = OSTALA_SI_UVIJEK_ISTA;}
            else if (artist == 'SVI PEVAJU JA NE CUJEM') {var urlCoverArt = SVI_PEVAJU_JA_NE_CUJEM;}
            else if (artist == 'TI SI PJESMA MOJE DUSE') {var urlCoverArt = TI_SI_PJESMA_MOJE_DUSE;}
            else if (artist == 'DALI SI SPAVALA') {var urlCoverArt = DALI_SI_SPAVALA;}
            else if (artist == 'DA ME NISI') {var urlCoverArt = DA_ME_NISI;}
            else if (artist == 'DIGNI RUKU') {var urlCoverArt = DIGNI_RUKU;}
            else if (artist == 'DODIRNI ME') {var urlCoverArt = DODIRNI_ME;}
            else if (artist == 'KAD ME POGLEDAS') {var urlCoverArt = KAD_ME_POGLEDAS;}
            else if (artist == 'KOTOR') {var urlCoverArt = KOTOR;}
            else if (artist == 'SKADARSKA') {var urlCoverArt = SKADARSKA;}
            else if (artist == 'TRUBE') {var urlCoverArt = TRUBE;}
            else if (artist == 'TI SAMO BUDI DOVOLNO DALEKO') {var urlCoverArt = TI_SAMO_BUDI_DOVOLJNO_DALEKO;}
            else if (artist == 'OSMIJEH') {var urlCoverArt = OSMIJEH;}
            else if (artist == 'KENOZOIK') {var urlCoverArt = KENOZOIK;}
            else if (artist == 'MALJCHIKI') {var urlCoverArt = MALJCHIKI;}
            else if (artist == 'LEJLA') {var urlCoverArt = LEJLA;}
            else if (artist == 'LUD SAM ZA TOBOM') {var urlCoverArt = LUD_SAM_ZA_TOBOM;}
            else if (artist == 'NEK NEBO NAM SUDI') {var urlCoverArt = NEK_NEBO_NAM_SUDI;}
            else if (artist == 'OSTAVI SUZE ZA KRAJ') {var urlCoverArt = OSTAVI_SUZE_ZA_KRAJ;}
            else if (artist == 'OTKAD TEBE NEMA') {var urlCoverArt = OTKAD_TEBE_NEMA;}
            else if (artist == 'RODJENA SI SAMO ZA MENE') {var urlCoverArt = RODJENA_SI_SAMO_ZA_MENE;}
            else if (artist == 'RUZMARIN') {var urlCoverArt = RUZMARIN;}
            else if (artist == 'STRAH ME DA TE VOLIM') {var urlCoverArt = STRAH_ME_DA_TE_VOLIM;}
            else if (artist == 'SVE LJUBAVI SU TUZNE') {var urlCoverArt = SVE_LJUBAVI_SU_TUZNE;}
            else if (artist == 'SVI MOJI DRUMOVI') {var urlCoverArt = SVI_MOJI_DRUMOVI;}
            else if (artist == 'TI ZNAS SVE') {var urlCoverArt = TI_ZNAS_SVE;}
            else if (artist == 'VOLIO BI DA TE NE VOLIM') {var urlCoverArt = VOLIO_BI_DA_TE_NE_VOLIM;}
            else if (artist == 'STRANAC U NOCI') {var urlCoverArt = STRANAC_U_NOCI;}
            else if (artist == 'POTRAZI ME U PREDGRADU') {var urlCoverArt = POTRAZI_ME_U_PREDGRADU;}
            else if (artist == 'SAMO SIMPATIJA') {var urlCoverArt = SAMO_SIMPATIJA;}
            else if (artist == 'ZORA JE') {var urlCoverArt = ZORA_JE;}
            else if (artist == 'STO CE TAJ COVJEK TU') {var urlCoverArt = STO_CE_TAJ_COVJEK_TU;}
            else if (artist == 'TESKA VREMENA PRIJATELJU MOJ') {var urlCoverArt = TESKA_VREMENA_PRIJATELJU_MOJ;}
            else if (artist == 'DOTAKNI ME USNAMA') {var urlCoverArt = DOTAKNI_ME_USNAMA;}
            else if (artist == 'RIJEKA SNOVA') {var urlCoverArt = RIJEKA_SNOVA;}
            else if (artist == 'SUNCAN DAN') {var urlCoverArt = SUNCAN_DAN;}
            else if (artist == 'KAVANNA FT FIUMENS') {var urlCoverArt = KAVANNA_FT_FIUMENS;}
            else if (artist == 'NAJDRAZE MOJE') {var urlCoverArt = NAJDRAZE_MOJE;}
            else if (artist == 'PLAVA KOSULJA') {var urlCoverArt = PLAVA_KOSULJA;}
            else if (artist == 'SUTI MOJ DJECACE PLAVI') {var urlCoverArt = SUTI_MOJ_DJECACE_PLAVI;}
            else if (artist == 'ZA DOBRA STARA VREMENA') {var urlCoverArt = ZA_DOBRA_STARA_VREMENA;}
            else if (artist == 'ZNAM') {var urlCoverArt = ZNAM;}
            else if (artist == 'BICU TVOJ') {var urlCoverArt = BICU_TVOJ;}
            else if (artist == 'BOBANE') {var urlCoverArt= BOBANE;}
            else if (artist == 'DODJE MI DA VRISNEM TVOJE IME') {var urlCoverArt = DODJE_MI_DA_VRISNEM_TVOJE_IME;}
            else if (artist == 'NIJE ZA NJU') {var urlCoverArt = NIJE_ZA_NJU;}
            else if (artist == 'ODLAZIM A VOLIM TE') {var urlCoverArt = ODLAZIM_A_VOLIM_TE;}
            else if (artist == 'OSLONI SE NA MENE') {var urlCoverArt = OSLONI_SE_NE_MENE;}
            else if (artist == 'PITAJU ME PITAJU') {var urlCoverArt = PITAJU_ME_PITAJU;}
            else if (artist == 'POMAGAJTE DRUGOVI') {var urlCoverArt = POMAGAJTE_DRUGOVI;}
            else if (artist == 'SMEJEM SE A PLAKAO BIH') {var urlCoverArt = SMEJEM_SE_A_PLAKAO_BIH;}
            else if (artist == 'ZBOG TEBE BIH TUCAO KAMEN') {var urlCoverArt = ZBOG_TEBE_BIH_TUCAO_KAMEN;}
            else if (artist == 'CRNI PLES') {var urlCoverArt = CRNI_PLES;}
            else if (artist == 'DENIS') {var urlCoverArt = DENIS;}
            else if (artist == 'NADJI ME') {var urlCoverArt = NADJI_ME;}
            else if (artist == 'SAM') {var urlCoverArt = SAM;}
            else if (artist == 'BROD U BOCI') {var urlCoverArt = BROD_U_BOCI;}
            else if (artist == 'CESARICA') {var urlCoverArt = CESARICA;}
            else if (artist == 'DVAPUT SAN UMRA') {var urlCoverArt = DVAPUT_SAN_UMRA;}
            else if (artist == 'KAD MI DODZES TI') {var urlCoverArt = KAD_MI_DODZES_TI;}
            else if (artist == 'NEBO MOJE') {var urlCoverArt = NEBO_MOJE;}
            else if (artist == 'NEDOSTAJES MI TI') {var urlCoverArt = NEDOSTAJES_MI_TI;}
            else if (artist == 'NOCTURNO') {var urlCoverArt = NOCTURNO;}
            else if (artist == 'PISMO MOJA') {var urlCoverArt = PISMO_MOJA;}
            else if (artist == 'PRED TVOJIM VRATIME') {var urlCoverArt = PRED_TVOJIM_VRATIMA;}
            else if (artist == 'STINE') {var urlCoverArt = STINE;}
            else if (artist == 'STO TO BJESE LJUBAV') {var urlCoverArt = STO_TO_BJESE_LJUBAV;}
            else if (artist == 'SVE BI DA ZA NJU') {var urlCoverArt = SVE_BI_DA_ZA_NJU;}
            else if (artist == 'SVIRAJTE NOCAS ZA MOJU DUSU') {var urlCoverArt = SVIRAJTE_NOCAS_ZA_MOJU_DUSU;}
            else if (artist == 'TRAG U BESKRAJU') {var urlCoverArt = TRAG_U_BESKRAJU;}
            else if (artist == 'VJERUJ U LJUBAV') {var urlCoverArt = VJERUJ_U_LJUBAV;}
            else if (artist == 'U LJUBAV VJERE NEMAM FT GIBONI') {var urlCoverArt = U_LJUBAV_VJERE_NEMAM_FT_GIBONNI;}
            else if (artist == 'DZENI') {var urlCoverArt = DZENI;}
            else if (artist == 'E DA SI BAREM NOCAS OVDJE') {var urlCoverArt = E_DA_SI_BAREM_NOCAS_OVDJE;}
            else if (artist == 'E MOJ SASA') {var urlCoverArt = E_MOJ_SASA;}
            else if (artist == 'JA SAM ZA PLES') {var urlCoverArt = JA_SAM_ZA_PLES;}
            else if (artist == 'JESEN JE') {var urlCoverArt = JESEN_JE;}
            else if (artist == 'MILENA') {var urlCoverArt = MILENA;}
            else if (artist == 'CARTE BLANCHE') {var urlCoverArt = CARTE_BLANCHE;}
            else if (artist == 'BEZ TEBE') {var urlCoverArt = BEZ_TEBE;}
            else if (artist == 'DITELINA S CETIRI LISTA') {var urlCoverArt = DITELINA_S_CETRI_LISTA;}
            else if (artist == 'JEDAN OD MNOGIH') {var urlCoverArt = JEDAN_OD_MNOGIH;}
            else if (artist == 'CALIFORNIA') {var urlCoverArt = CALIFORNIA;}
            else if (artist == 'JEANS GENERACIJA') {var urlCoverArt = JEANS_GENERACIJA;}
            else if (artist == 'KAKVA NOC') {var urlCoverArt = KAKVA_NOC;}
            else if (artist == 'DZEMPER ZA VINOGRAD') {var urlCoverArt = DZEMPER_ZA_VINOGRAD;}
            else if (artist == 'KAD BI DOSLA MARIJA') {var urlCoverArt = KAD_BI_DOSLA_MARIJA;}
            else if (artist == 'OD DRUGA DO DRUGA') {var urlCoverArt = OD_DRUGA_DO_DRUGA;}
            else if (artist == 'VINO NOCI FT DEMODE') {var urlCoverArt = VINO_NOCI_FT_DEMODE;}
            else if (artist == 'KOLACICI') {var urlCoverArt = KOLACICI;}
            else if (artist == 'DA MI JE BITI MORSKI PAS') {var urlCoverArt = DA_MI_JE_BITI_MORSKI_PAS;}
            else if (artist == 'AKO JEDNOM CIDIS MARIJU') {var urlCoverArt = AKO_JEDNOM_VIDIS_MARIJU;}
            else if (artist == 'KAD BIH ZNAO DA JE SAMA') {var urlCoverArt = KAD_BIH_ZNAO_DA_JE_SAMA;}
            else if (artist == 'AKO OVO JE KRAJ FT DAVOR DRAGOJEVIC') {var urlCoverArt = AKO_OVO_JE_KRAJ_FT_DAVOR_DRAGOJEVIC;}
            else if (artist == 'APSOLUTNO TVOJ') {var urlCoverArt = APSOLUTNO_TVOJ;}
            else if (artist == 'JA IMAM TE A KO DA NEMAM TE') {var urlCoverArt = JA_IMAM_TE_A_KO_DA_NEMAM_TE;}
            else if (artist == 'PRSTEN I ZLATNI LANAC') {var urlCoverArt = PRSTEN_I_ZLATNI_LANAC;}
            else if (artist == 'STO JE BILO BILO JE') {var urlCoverArt = STO_JE_BILO_BILO_JE;}
            else if (artist == 'ZUTE DUNJE') {var urlCoverArt = ZUTE_DUNJE;}
            else if (artist == 'STO TE NEMA') {var urlCoverArt = STO_TE_NEMA;}
            else if (artist == 'SVE SMO MOGLI MI') {var urlCoverArt = SVE_SMO_MOGLI_MI;}
            else if (artist == 'JA SAM TI JEDINI DRUG') {var urlCoverArt = JA_SAM_TI_JEDINI_DRUG;}
            else if (artist == 'NA OBALI') {var urlCoverArt = NA_OBALI;}
            else if (artist == 'SKITNICA') {var urlCoverArt = SKITNICA;}
            else if (artist == 'DODZI U MALI KAFE') {var urlCoverArt = DODZI_U_MALI_KAFE;}
            else if (artist == 'GOVOR TVOGA TELA') {var urlCoverArt = GOVOR_TVOGA_TELA;}
            else if (artist == 'LJULJAJ ME NEZNO') {var urlCoverArt = LJULJAJ_ME_NEZNO;}
            else if (artist == 'PROBAJ ME') {var urlCoverArt = PROBAJ_ME;}
            else if (artist == 'GDE DA POBEGNEM') {var urlCoverArt = GDE_DA_POBEGNEM;}
            else if (artist == 'MARIJA') {var urlCoverArt = MARIJA;}
            else if (artist == 'MOZDA NEBO ZNA') {var urlCoverArt = MOZDA_NEBO_ZNA;}
            else if (artist == 'S KIM CEKAS DAN') {var urlCoverArt = S_KIM_CEKAS_DAN;}
            else if (artist == 'VINO CRVENO') {var urlCoverArt = VINO_CRVENO;}
            else if (artist == 'IVANA') {var urlCoverArt = IVANA;}
            else if (artist == 'DODJI') {var urlCoverArt = DODJI;}
            else if (artist == 'DOK SI PORED MENE') {var urlCoverArt = DOK_SI_PORED_MENE;}
            else if (artist == 'JESEN_U_MENI') {var urlCoverArt = JESEN_U_MENI;}
            else if (artist == 'KADA ME DOTAKNE') {var urlCoverArt = KADA_ME_DOTAKNE;}
            else if (artist == 'KAO TI') {var urlCoverArt = KAO_TI;}
            else if (artist == 'LJUBAVNA') {var urlCoverArt = LJUBAVNA;}
            else if (artist == 'LUTKA ZA BAL') {var urlCoverArt = LUTKA_ZA_BAL;}
            else if (artist == 'MOJA JE PJESMA LAGANA') {var urlCoverArt = MOJA_JE_PJESMA_LAGANA;}
            else if (artist == 'NEDA') {var urlCoverArt = NEDA;}
            else if (artist == 'PROKLETA NEDELJA') {var urlCoverArt = PROKLETA_NEDELJA;}
            else if (artist == 'SVE JOS MIRISE NA NJU') {var urlCoverArt = SVE_JOS_MIRISE_NA_NJU;}
            else if (artist == 'U LJUBAV VJERUJEM') {var urlCoverArt = U_LJUBAV_VJERUJEM;}
            else if (artist == 'UGASI ME') {var urlCoverArt = UGASI_ME;}
            else if (artist == 'UHVATI RITAM') {var urlCoverArt = UHVATI_RITAM;}
            else if (artist == 'ZASTAVE') {var urlCoverArt = ZASTAVE;}
            else if (artist == 'STRANICE DNEVNIKA') {var urlCoverArt = STRANICE_DNEVNIKA;}
            else if (artist == 'DOLAZIM ZA 5 MINUTA') {var urlCoverArt = DOLAZIM_ZA_5_MINUTA;}
            else if (artist == 'NAJ JACI OSTAJU') {var urlCoverArt = NAJ_JACI_OSTAJU;}
            else if (artist == 'POVEDI ME U NOC') {var urlCoverArt = POVEDI_ME_U_NOC;}
            else if (artist == 'SVEMU DODJE KRAJ') {var urlCoverArt = SVEMU_DODJE_KRAJ;}
            else if (artist == 'TI I JA') {var urlCoverArt = TI_I_JA;}
            else if (artist == 'BI MOGO DA MOGU') {var urlCoverArt = BI_MOGO_DA_MOGU;}
            else if (artist == 'ENA') {var urlCoverArt = ENA;}
            else if (artist == 'MOJA PRVA LJUBAV') {var urlCoverArt = MOJA_PRVA_LJUBAV;}
            else if (artist == 'SAL OD SVILE') {var urlCoverArt = SAL_OD_SVILE;}
            else if (artist == 'SEJN') {var urlCoverArt = SEJN;}
            else if (artist == 'UZALUD PITAS') {var urlCoverArt = UZALUD_PITAS;}
            else if (artist == 'LAGANO UMIREM') {var urlCoverArt = LAGANO_UMIREM;}
            else if (artist == 'CEKALA SAM') {var urlCoverArt = CEKALA_SAM;}
            else if (artist == 'NE LOMI ME') {var urlCoverArt = NE_LOMI_ME;}
            else if (artist == 'RUZMARIN') {var urlCoverArt = RUZMARIN;}

            else if (artist == 'CINI MI SE DA') {var urlCoverArt = CINI_MI_SE_DA;}
            else if (artist == 'KADA SANJAMO') {var urlCoverArt = KADA_SANJAMO;}
            else if (artist == 'NEVERNA SI') {var urlCoverArt = NEVERNA_SI;}
            else if (artist == 'TO JE SUDBINA') {var urlCoverArt = TO_JE_SUDBINA;}
            else if (artist == 'KAO PTICA NA MOM DLANU') {var urlCoverArt = KAO_PTICA_NA_MOM_DLANU;}
            else if (artist == 'TAJNA JE U TEBI SKRIVENA') {var urlCoverArt = TAJNA_JE_U_TEBI_SKRIVENA;}
            else if (artist == 'ZABORAVLJENI') {var urlCoverArt = ZABORAVLJENI;}
            else if (artist == 'AKO SU TO SAMO BILE LAZI') {var urlCoverArt = AKO_SU_TO_SAMO_BILE_LAZI;}
            else if (artist == 'BOLJE BITI PIJAN NEGO STAR') {var urlCoverArt = BOLJE_BITI_PIJAN_NEGO_STAR;}
            else if (artist == 'KAJA') {var urlCoverArt = KAJA;}
            else if (artist == 'LJUBI SE ISTOK I ZAPAD') {var urlCoverArt = LJUBI_SE_ISTOK_I_ZAPAD;}
            else if (artist == 'LOVAC I KOSUTA') {var urlCoverArt = LOVAC_I_KOSUTA;}
            else if (artist == 'GRUDI BALKANSKE') {var urlCoverArt = GRUDI_BALKANSKE;}
            else if (artist == 'NATASA') {var urlCoverArt = NATASA;}
            else if (artist == 'VRATI SE') {var urlCoverArt = VRATI_SE;}
            else if (artist == 'FRIDA') {var urlCoverArt = FRIDA;}
            else if (artist == 'JEDNA MALA PLAVA') {var urlCoverArt = JEDNA_MALA_PLAVA;}
            else if (artist == 'PRINCEZA FT DADO TOPIC') {var urlCoverArt = PRINCEZA_FT_DADO_TOPIC;}
            else if (artist == 'ODLAZIM') {var urlCoverArt = ODLAZIM;}
            else if (artist == 'SAVA TIHO TECE') {var urlCoverArt = SAVA_TIHO_TECE;}
            else if (artist == 'SUADA') {var urlCoverArt = SUADA;}
            else if (artist == 'ZELENE SU BILE OCI TE') {var urlCoverArt = ZELENE_SU_BILE_OCI_TE;}
            else if (artist == 'DECKO AJDE OLADI') {var urlCoverArt = DECKO_AJDE_OLADI;}
            else if (artist == 'SRCE OD MEDA') {var urlCoverArt = SRCE_OD_MEDA;}
            else if (artist == 'TAXI') {var urlCoverArt = TAXI;}
            else if (artist == 'JELENI UMIRU SAMI') {var urlCoverArt = JELENI_UMIRU_SAMI;}
            else if (artist == 'IZ NEKIH STARIH RAZLOGA') {var urlCoverArt = IZ_NEKIH_STARIH_RAZLOGA;}
            else if (artist == 'NE ZOVI MAMA DOKTORA') {var urlCoverArt = NE_ZOVI_MAMA_DOKTORA;}
            else if (artist == 'CRNO BIJELI SVIJET') {var urlCoverArt = CRNO_BIJELI_SVIJET;}
            else if (artist == 'KISE JESENJE') {var urlCoverArt = KISE_JESENJE;}
            else if (artist == 'KORAK OD SNA') {var urlCoverArt = KORAK_OD_SNA;}
            else if (artist == 'MA KOG ME BOGA ZA TEBE PITAJU') {var urlCoverArt = MA_KOG_ME_BOGA_ZA_TEBE_PITAJU;}
            else if (artist == 'MARINA') {var urlCoverArt = MAR_INA;}
            else if (artist == 'MI PLESEMO') {var urlCoverArt = MI_PLESEMO;}
            else if (artist == 'MOJ BIJELI LABUDE') {var urlCoverArt = MOJ_BIJELI_LABUDE;}
            else if (artist == 'S VREMENA NA VRIJEME') {var urlCoverArt = S_VREMENA_NA_VRIJEME;}
            else if (artist == 'UZALUD VAM TRUD SVIRACI') {var urlCoverArt = UZALUD_VAM_TRUD_SVIRACI;}
            else if (artist == 'ZAUSTAVITE ZEMLJU') {var urlCoverArt = ZAUSTAVITE_ZEMLJU;}
            else if (artist == 'AKO TRAZIS NEKOGA') {var urlCoverArt = AKO_TRAZIS_NEKOGA;}
            else if (artist == 'TU NOC KAD SI SE UDAVALA') {var urlCoverArt = TU_NOC_KAD_SI_SE_UDAVALA;}
            else if (artist == 'ZBOG MENE NE PLACI') {var urlCoverArt = ZBOG_MENE_NE_PLACI;}
            else if (artist == 'LOLA') {var urlCoverArt = LOLA;}
            else if (artist == 'TUZNA SU ZELENA POLJA') {var urlCoverArt = TUZNA_SU_ZELENA_POLJA;}
            else if (artist == 'JA VBOLIM SAMO SEBE') {var urlCoverArt = JA_VOLIM_SAMO_SEBE;}
            else if (artist == 'ANDREA') {var urlCoverArt = ANDREA;}
            else if (artist == 'AL KAPONE') {var urlCoverArt = AL_KAPONE;}
            else if (artist == 'AMSTERDAM') {var urlCoverArt = AMSTERDAM;}
            else if (artist == 'AVIONU SLOMICU TI KRILA') {var urlCoverArt = AVIONU_SLOMICU_TI_KRILA;}
            else if (artist == 'DOBRO JUTRO') {var urlCoverArt = DOBRO_JUTRO;}
            else if (artist == 'DVA DINARA DRUZE') {var urlCoverArt = DVA_DINARA_DRUZE;}
            else if (artist == 'GDE SI U OVOM GLUPOM HOTELU') {var urlCoverArt = GDE_SI_U_OVOM_GLUPOM_HOTELU;}
            else if (artist == 'JA JE GLEDAM KAKO SPAVA') {var urlCoverArt = JA_JE_GLEDAM_KAKO_SPAVA;}
            else if (artist == 'JA SAM SE LOZIO NA TEBE') {var urlCoverArt = JA_SAM_SE_LOZIO_NA_TEBE;}
            else if (artist == 'KAD HODAS') {var urlCoverArt = KAD_HODAS;}
            else if (artist == 'KAD SAM BIO MLAD') {var urlCoverArt = KAD_SAM_BIO_MLAD;}
            else if (artist == 'KAD PADNE NOC') {var urlCoverArt = KADA_PADNE_NOC;}
            else if (artist == 'KAKO JE LEPO BITI GLUP') {var urlCoverArt = KAKO_JE_LEPO_BITI_GLUP;}
            else if (artist == 'LUTKA SA NASLOVNE STRANE') {var urlCoverArt = LUTKA_SA_NASLOVNE_STRANE;}
            else if (artist == 'NA ZAPADU NISTA NOVO') {var urlCoverArt = NA_ZAPADU_NISTA_NOVO;}
            else if (artist == 'NEMOJ DA IDES MOJOM ULICOM') {var urlCoverArt = NEMOJ_DA_IDES_MOJOM_ULICOM;}
            else if (artist == 'NEMOJ SRECENO NEMOJ DANAS') {var urlCoverArt = NEMOJ_SRECO_NEMOJ_DANAS;}
            else if (artist == 'OSTACU SLOBODAN') {var urlCoverArt = OSTACU_SLOBODAN;}
            else if (artist == 'OSTANI DZUBRE DO KRAJA') {var urlCoverArt = OSTANI_DZUBRE_DO_KRAJA;}
            else if (artist == 'POGLEDAJ DOM SVOJ ANDJELE') {var urlCoverArt = POGLEDAJ_DOM_SVOJ_ANDJELE;}
            else if (artist == 'PRAVILA PRAVILA') {var urlCoverArt = PRAVILA_PRAVILA;}
            else if (artist == 'VOLIM VOLIM ZENE') {var urlCoverArt = VOLIM_VOLIM_ZENE;}
            else if (artist == 'COKOLADA') {var urlCoverArt = COKOLADA;}
            else if (artist == 'DEVOJKO MALA') {var urlCoverArt = DEVOJKO_MALA;}
            else if (artist == 'MALENA') {var urlCoverArt = MALENA;}
            else if (artist == 'ONA TO ZNA') {var urlCoverArt = ONA_TO_ZNA;}
            else if (artist == 'BACILA JE SVE NIZ RIJEKU') {var urlCoverArt = BACILA_JE_SVE_NIZ_RIJEKU;}
            else if (artist == 'BALADA') {var urlCoverArt = BALADA;}
            else if (artist == 'DA SAM JA NETKO') {var urlCoverArt = DA_SAM_JA_NETKO;}
            else if (artist == 'PREDAJ SE SRCE') {var urlCoverArt = PREDAJ_SE_SRCE}
            else if (artist == 'SANJAM') {var urlCoverArt = SANJAM;}
            else if (artist == 'SVE OVE GODINE') {var urlCoverArt = SVE_OVE_GODINE;}
            else if (artist == 'TI SI MI BILA NAJ NAJ') {var urlCoverArt = TI_SI_MI_BILA_NAJ_NAJ;}
            else if (artist == 'DANAS SAM LUDA') {var urlCoverArt = DANAS_SAM_LUDA;}
            else if (artist == 'GDJE DUNAV LJUBIO NEBO') {var urlCoverArt = GDJE_DUNAV_LJUBI_NEBO;}
            else if (artist == 'MAGLA') {var urlCoverArt = MAGLA;}
            else if (artist == 'NOCNA PTICA') {var urlCoverArt = NOCNA_PTICA;}
            else if (artist == 'O JEDNOJ MLADOSTI') {var urlCoverArt = O_JEDNOJ_MLADOSTI;}
            else if (artist == 'RUSILA SAM MOSTOVE FT DINO DVORNIK') {var urlCoverArt = RUSILA_SAM_MOSTOVE_FT_DINO_DVORNIK;}
            else if (artist == 'CAO AMORE FT VLADO KALEMBAR') {var urlCoverArt = CAO_AMORE_FT_VLADO_KALEMBAR;}
            else if (artist == 'POVEDI ME') {var urlCoverArt = POVEDI_ME;}
            else if (artist == 'ANA') {var urlCoverArt = ANA;}
            else if (artist == 'JA NISAM KOCKAR') {var urlCoverArt = JA_NISAM_KOCKAR;}
            else if (artist == 'ZAKUNI SE LJUAVI') {var urlCoverArt = ZAKUNI_SE_LJUBAVI;}
            else if (artist == 'CRNA DANA') {var urlCoverArt = CRNA_DAMA;}
            else if (artist == 'DAIRE') {var urlCoverArt = DAIRE;}
            else if (artist == 'KOKETA') {var urlCoverArt = KOKETA;}
            else if (artist == 'VOLIO SAM TANJU') {var urlCoverArt = VOLIO_SAM_TANJU;}
            else if (artist == 'S VREMENA NA VREME') {var urlCoverArt = S_VREMENA_NA_VREME;}
            else if (artist == 'KOFER LJUBAVI') {var urlCoverArt = KOFER_LJUBAVI;}
            else if (artist == 'RODJENI') {var urlCoverArt = RODJENI;}
            else if (artist == 'DALEKO') {var urlCoverArt = DALEKO;}
            else if (artist == 'DUSO MOJA') {var urlCoverArt = DUSO_MOJA;}
            else if (artist == 'JEDNE NOCI U DECEMBRU') {var urlCoverArt = JEDNE_NOCI_U_DECEMBRU;}
            else if (artist == 'NAPISI JEDNU LJBAVNU') {var urlCoverArt = NAPISI_JEDNU_LJUBAVNU;}
            else if (artist == 'NIJE HTELA') {var urlCoverArt = NIJE_HTJELA;}
            else if (artist == 'OVAKO NE MOGU DALJE') {var urlCoverArt = OVAKO_NE_MOGU_DALJE;}
            else if (artist == 'VRATIO SAM SE ZIVOTE') {var urlCoverArt = VRATIO_SAM_SE_ZIVOTE;}
            else if (artist == 'BOLJE DA SAM DRUGE LJUBIO') {var urlCoverArt = BOLJE_DA_SAM_DRUGE_LJUBIO;}
            else if (artist == 'COVEK OD MEDA') {var urlCoverArt = COVEK_OD_MEDA;}
            else if (artist == 'HAJDE DA SE VOLIMO') {var urlCoverArt = HAJDE_DA_SE_VOLIMO;}
            else if (artist == 'NA RASKRSCU') {var urlCoverArt = NA_RASKRSCU;}
            else if (artist == 'RATNE IGRE') {var urlCoverArt = RATNE_IGRE;}
            else if (artist == 'PLAVUSA') {var urlCoverArt = PLAVUSA;}
            else if (artist == 'ZBOG JEDNE DIVNE CRNE ZENE') {var urlCoverArt = ZBOG_JEDNE_DIVNE_CRNE_ZENE;}
            else if (artist == 'POKRENI ME') {var urlCoverArt = POKRENI_ME;}
            else if (artist == 'SIZIKA') {var urlCoverArt = SIZIKA;}
            else if (artist == 'AJDE AJDE JASMINA') {var urlCoverArt = AJDE_AJDE_JASMINA;}
            else if (artist == 'APRIL U BEOGRADU') {var urlCoverArt = APRIL_U_BEOGRADU;}
            else if (artist == 'CINI MI SE GRMI') {var urlCoverArt = CINI_MI_SE_GRMI;}
            else if (artist == 'DA TI KAZEM STA MI JE') {var urlCoverArt = DA_TI_KAZEM_STA_MI_JE;}
            else if (artist == 'GORI VATRA') {var urlCoverArt = GORI_VATRA;}
            else if (artist == 'KAD BI MOJA BILA') {var urlCoverArt = KAD_BI_MOJA_BILA;}
            else if (artist == 'MADJARICA') {var urlCoverArt = MADJARICA;}
            else if (artist == 'MALO POJACAJ RADIO') {var urlCoverArt = MALO_POJACAJ_RADIO;}
            else if (artist == 'PISACU JOJ PISMA DUGA') {var urlCoverArt = PISACU_JOJ_PISMA_DUGA;}
            else if (artist == 'RIJEKA SUZA I NA NJOJ LADJA') {var urlCoverArt = RIJEKA_SUZA_I_NA_NJOJ_LADJA;}
            else if (artist == 'RUSKA') {var urlCoverArt = RUSKA;}
            else if (artist == 'SINOC NISI BILA TU') {var urlCoverArt = SINOC_NISI_BILA_TU;}
            else if (artist == 'STA MI RADIS') {var urlCoverArt = STA_MI_RADIS;}
            else if (artist == 'ZIVIS U OBLACIMA') {var urlCoverArt = ZIVIS_U_OBLACIMA;}
            else if (artist == 'DA LI ZNAS DA TE VOLIM') {var urlCoverArt = DA_LI_ZNAS_DA_TE_VOLIM;}
            else if (artist == 'MAKEDONIJA') {var urlCoverArt = MAKEDONIJA;}
            else if (artist == 'ZDENKA KOVACICEK') {var urlCoverArt = ZDENKA_KOVACICEK;}
            else if (artist == 'SEDAMNEST TI JE GODINA FT HARI MATA HARI') {var urlCoverArt = SEDAMNEST_TI_JE_GODINA_FT_HARI_MATA_HARI;}
            else if (artist == 'DVIJE ZVJEZDICE') {var urlCoverArt = DVIJE_ZVJEZDICE;}
            else if (artist == 'MILION GODINA') {var urlCoverArt = MILION_GODINA;}
            else if (artist == 'MOJ MALI JE OPASAN') {var urlCoverArt = MOJ_MALI_JE_OPASAN;}
            else if (artist == 'NEMA VISE LJUBAVI') {var urlCoverArt = NEMA_VISE_LJUBAVI;}
            else if (artist == 'MOJA POSLEDNJA I PRVA LJUBAVI') {var urlCoverArt = MOJA_POSLEDNJA_I_PRVA_LJUBAVI;}
            else if (artist == 'PRIJATELJI STARI GDJE STE') {var urlCoverArt = PRIJATELJI_STARI_GDJE_STE;}
            else if (artist == 'DESET GODINA') {var urlCoverArt = DESET_GODINA;}
            else if (artist == 'SRCE SRNE KOJA DRHTI') {var urlCoverArt = SRCE_SRNE_KOJA_DRHTI;}
            else if (artist == 'KRILA LEPTIRA') {var urlCoverArt = KRILA_LEPTIRA;}
            else if (artist == 'BILO MI JE LIJEPO S TOBOM') {var urlCoverArt = BILO_MI_JE_LIJEPO_S_TOBOM;}
            else if (artist == 'NE MOZE TO TAKO') {var urlCoverArt = NE_MOZE_TO_TAKO;}
            else if (artist == 'NE DAJ MI DA GOVORIM U SNU') {var urlCoverArt = NE_DAJ_MI_DA_GOVORIM_U_SNU;}
            else if (artist == 'OKA TVOJA DVA') {var urlCoverArt = OKA_TVOJA_DVA;}
            else if (artist == 'DETEKTIVSKA PRICA') {var urlCoverArt = DETEKTIVSKA_PRICA;}
            else if (artist == 'IZNENADI ME') {var urlCoverArt = IZNENADI_ME;}
            else if (artist == 'OD ZLATA JABUKA') {var urlCoverArt = OD_ZLATA_JABUKA;}
            else if (artist == 'TOTALNO DRUKCIJI OD DRUGIH') {var urlCoverArt = TOTALNO_DRUKCIJI_OD_DRUGIH;}
            else if (artist == 'VLAK') {var urlCoverArt = VLAK;}
            else if (artist == 'DUNAVOM JOS SIBAJU VETROVI') {var urlCoverArt = DUNAVOM_JOS_SIBAJU_VETROVI;}
            else if (artist == 'KOME SA RADUJES') {var urlCoverArt = KOME_SE_RADUJES;}
            else if (artist == 'CRNI LEPTIR') {var urlCoverArt = CRNI_LEPTIR;}
            else if (artist == 'MORNAR') {var urlCoverArt = MORNAR;}
            else if (artist == 'ZA MILION GODINA') {var urlCoverArt = ZA_MILION_GODINA;}
            else if (artist == 'BALADA O PISONJI I ZUGI') {var urlCoverArt = BALADA_O_PISONJI_I_ZUGI;}
            else if (artist == 'DJEVOJCICE KOJIMA MIRISE KOZA') {var urlCoverArt = DJEVOJCICE_KOJIMA_MIRISE_KOZA;}
            else if (artist == 'HADZIJA ILI BOS') {var urlCoverArt = HADZIJA_ILI_BOS;}
            else if (artist == 'JUGO 45') {var urlCoverArt = JUGO_45;}
            else if (artist == 'MOZES IMAT MOJE TIJELO') {var urlCoverArt = MOZES_IMAT_MOJE_TIJELO;}
            else if (artist == 'ZENICA BLUES') {var urlCoverArt = ZENICA_BLUES;}
            else if (artist == 'DODIRNI MI KOLENA') {var urlCoverArt = DODIRNI_MI_KOLENA;}
            else if (artist == 'JABUKE I VINO') {var urlCoverArt = JABUKE_I_VINO;}
            else if (artist == 'MAJSTOR ZA POLJUPCE') {var urlCoverArt = MAJSTOR_ZA_POLJUPCE;}
            else if (artist == 'MLADICU MOJ') {var urlCoverArt = MLADICU_MOJ;}
            else if (artist == 'NAJDE DA LUDUJEMO') {var urlCoverArt = HAJDE_DA_LUDUJEMO;}
            else if (artist == 'TI NEMAS PRAVA NA MENE') {var urlCoverArt = TI_NEMAS_PRAVA_NA_MENE;}
            else if (artist == 'NE BOJIM SE DRUGOVA TVOGA FRAJERA') {var urlCoverArt = NE_BOJIM_SE_DRUGOVA_TVOGA_FRAJERA;}
            else if (artist == 'STVARI LAGANE') {var urlCoverArt = STVARI_LAGANE;}
            else if (artist == 'TI ME IZLUDUJES') {var urlCoverArt = TI_ME_IZLUDUJES;}
            else if (artist == 'A TI SI MANGUP') {var urlCoverArt = A_TI_SI_MANGUP;}
            else if (artist == 'IMAM JEDAN SVIJET') {var urlCoverArt = IMA_JEDAN_SVIJET;}
            else if (artist == 'SVE JE NEOVICNO AKO TE VOLIM') {var urlCoverArt = SVE_JE_NEOBICNO_AKO_TE_VOLIM;}
            else if (artist == 'STIPU GATIBO') {var urlCoverArt = STIPU_GATIBO;}
            else if (artist == 'STO NE ZNAM GDE SI SAD') {var urlCoverArt = STO_NE_ZNAM_GDE_SI_SAD;}
            else if (artist == 'VOJAN POSTA') {var urlCoverArt = VOJAN_POSTA;}
            else if (artist == 'ZNAM I OSECAM') {var urlCoverArt = ZNAM_I_OSECAM;}
            else if (artist == 'OZENICES SE TI') {var urlCoverArt = OZENICES_SE_TI;}
            else if (artist == 'RUKUJU SE RUKUJU') {var urlCoverArt = RUKUJU_SE_RUKUJU;}
            else if (artist == 'ZANA VEJTE SNEGOVI') {var urlCoverArt = ZANA_VEJTE_SNEGOVI;}
            else if (artist == 'RAT I MIR') {var urlCoverArt = RAT_I_MIR;}
            else if (artist == 'ARIJA') {var urlCoverArt = ARIJA;}
            else if (artist == 'BARAKUDA') {var urlCoverArt = BARAKUDA;}
            else if (artist == 'DAJ NE PITAJ') {var urlCoverArt = DAJ_NE_PITAJ;}
            else if (artist == 'SAMO TERAJ TI PO SVOME') {var urlCoverArt = SAMO_TERAJ_TI_PO_SVOME;}
            else if (artist == 'VINO NA USNAMA') {var urlCoverArt = VINO_NA_USNAMA;}
            else if (artist == 'TROJE') {var urlCoverArt = TROJE;}
            else if (artist == 'NIKAD TE NIKO NECE VOLET KO JA') {var urlCoverArt = NIKAD_TE_NIKO_NECE_VOLJET_KO_JA;}
            else if (artist == 'NEKO TE IMA') {var urlCoverArt = NEKO_TE_IMA;}
            else if (artist == 'ZLATNA RIBICA') {var urlCoverArt = ZLATNA_RIBICA;}
            else if (artist == 'PONEKAD NOCU DOK SPAVA GRAD') {var urlCoverArt = PONEKAD_NOCU_DOK_SPAVA_GRAD;}
            else if (artist == 'IDU PTICE SELICE') {var urlCoverArt = IDU_PTICE_SELICE;}
            else if (artist == 'NE MOGU NE MOGU') {var urlCoverArt = NE_MOGU_NE_MOGU;}
            else if (artist == 'PILE MOJE') {var urlCoverArt = PILE_MOJE;}
            else if (artist == 'SAMO SKLOPI OKICE') {var urlCoverArt = SAMO_SKLOPI_OKICE;}
            else if (artist == 'VOLM TE JOS') {var urlCoverArt = VOLIM_TE_JOS;}
            else if (artist == 'IZGLEDA DA MI SMO SAMI') {var urlCoverArt = IZGLEDA_DA_MI_SMO_SAMI;}
            else if (artist == 'KOLIKO IMAS GODINA') {var urlCoverArt = KOLIKO_IMAS_GODINA;}
            else if (artist == 'NOVE GODINE') {var urlCoverArt = NOVE_GODINE;}
            else if (artist == 'O_JE') {var urlCoverArt = O_JE;}
            else if (artist == 'SIDJI DO REKE') {var urlCoverArt = SIDJI_DO_REKE;}
            else if (artist == 'JUZNJACI') {var urlCoverArt = JUZNJACI;}
            else if (artist == 'OKANO') {var urlCoverArt = OKANO;}
            else if (artist == 'PRAVA STVAR') {var urlCoverArt = PRAVA_STVAR;}
            else if (artist == 'TI MOZES SVE') {var urlCoverArt = TI_MOZES_SVE;}
            else if (artist == 'TI SI MI U KRVI') {var urlCoverArt = TI_SI_MI_U_KRVI;}
            else if (artist == 'AJDE AJDE IDI') {var urlCoverArt = AJDE_AJDE_IDI;}
            else if (artist == 'HOTEL BALKAN') {var urlCoverArt = HOTEL_BALKAN;}
            else if (artist == 'KRASIVA') {var urlCoverArt = KRASIVA;}
            else if (artist == 'NOC MI TE DUGUJE') {var urlCoverArt = NOC_MI_TE_DUGUJE;}
            else if (artist == 'OJ DEVOJKO SELEN VELEN') {var urlCoverArt = OJ_DEVOJKO_SELEN_VELEN;}
            else if (artist == 'JEDINA') {var urlCoverArt = JEDINA;}
            else if (artist == 'PJEVAM DANJU PJEVAM NOCU') {var urlCoverArt = PJEVAM_DANJU_PJEVAM_NOCU;}
            else if (artist == 'ZVAO SAM JE EMILI') {var urlCoverArt = ZVAO_SAM_JE_EMILI;}
            else if (artist == 'CAJE SUKARIJE') {var urlCoverArt = CAJE_SUKARIJE;}
            else if (artist == 'CIJA JE ONA ZVIJEZDA') {var urlCoverArt = CIJA_JE_ONO_ZVIJEZDA;}
            else if (artist == 'E DRAGA DRAGA') {var urlCoverArt = E_DRAGA_DRAGA;}
            else if (artist == 'GLAVO LUDA') {var urlCoverArt = GLAVO_LUDA;}
            else if (artist == 'JEDINA ZIMA SA KRISTINOM') {var urlCoverArt = JEDNA_ZIMA_SA_KRISTINOM;}
            else if (artist == 'MASLINASTO ZELENA') {var urlCoverArt = MASLINASTO_ZELENA;}
            else if (artist == 'MASTILO I VODA') {var urlCoverArt = MASTILO_I_VODA;}
            else if (artist == 'NEGDJE NE DNU SRCA') {var urlCoverArt = NEGDJE_NA_DNU_SRCA;}
            else if (artist == 'PRODUZI DALJE') {var urlCoverArt = PRODUZI_DALJE;}
            else if (artist == 'STANICA PODLUGOVI') {var urlCoverArt = STANICA_PODLUGOVI;}
            else if (artist == 'ZAGRLI ME') {var urlCoverArt = ZAGRLI_ME;}
            else if (artist == 'ZBOG TEBE') {var urlCoverArt = ZBOG_TEBE;}
            else if (artist == 'DA JE SRECE BILO') {var urlCoverArt = DA_JE_SRECE_BILO;}
            else if (artist == 'KUCKA NEVERNA') {var urlCoverArt = KUCKA_NEVERNA;}
            else if (artist == 'MENE TJERA NEKI VRAG') {var urlCoverArt = MENE_TJERA_NEKI_VRAG;}
            else if (artist == 'OPROSTI MI STO TE VOLIM') {var urlCoverArt = OPROSTI_MI_STO_TE_VOLIM;}
            else if (artist == 'TIJANA') {var urlCoverArt = TIJANA;}
            else if (artist == 'SINOC SAM POLA KAFANE POPIO') {var urlCoverArt = SINOC_SAM_POLA_KAFANE_POPIO;}
            else if (artist == 'OVE NOCI JEDNA ZENA') {var urlCoverArt = OVE_NOCI_JEDNA_ZENA;}
            else if (artist == 'GRADSKE CURE') {var urlCoverArt = GRADSKE_CURE;}
            else if (artist == 'KAKVA NOC') {var urlCoverArt = KAKVA_NOC;}
            else if (artist == 'DOBRE DEVOJKE') {var urlCoverArt = DOBRE_DEVOJKE;}
            else if (artist == 'BALKANSKA ULICA') {var urlCoverArt = BALKANSKA_ULICA;}
            else if (artist == 'KAKO SAM TE VOLJELA') {var urlCoverArt = KAKO_SAM_TE_VOLJELA;}
            else if (artist == 'STO SAM JA STO SI TI') {var urlCoverArt = STO_SAM_JA_STO_SI_TI;}
            else if (artist == 'RANO') {var urlCoverArt = RANO;}
            else if (artist == 'ROCK ME') {var urlCoverArt = ROCK_ME;}
            else if (artist == 'KUCA PORED MORA') {var urlCoverArt = KUCA_PORED_MORA;}
            else if (artist == 'PJEVALI SMO PJESME STARE') {var urlCoverArt = PJEVALI_SMO_PJESME_STARE;}
            else if (artist == 'POZOVI ME') {var urlCoverArt = POZOVI_ME;}
            else if (artist == 'IBRO DIRKA') {var urlCoverArt = IBRO_DIRKA;}
            else if (artist == 'MENI MAMA NE DA') {var urlCoverArt = MENI_MAMA_NE_DA;}
            else if (artist == 'RADOSTAN DAN') {var urlCoverArt = RADOSTAN_DAN;}
            else if (artist == 'MOZDA MOZDA') {var urlCoverArt = MOZDA_MOZDA;}
            else if (artist == 'LJUBAV NIJE ZA NAS') {var urlCoverArt = LJUBAV_NIJE_ZA_NAS;}
            else if (artist == 'JEDAN COVEK JEDNA ZENA') {var urlCoverArt = JEDAN_COVEK_JEDNA_ZENA;}
            else if (artist == 'GALEBOVI') {var urlCoverArt = GALEBOVI;}
            else if (artist == 'JELENA') {var urlCoverArt = JELENA;}
            else if (artist == 'GLASNO GLASNIJE') {var urlCoverArt = GLASNO_GLASNIJE;}
            else if (artist == 'OD SPLITA DO BEOGRADA FT DINO DVORNIK') {var urlCoverArt = OD_SPLITA_DO_BEOGRADA_FT_DINO_DVORNIK;}
            else if (artist == 'PISMO') {var urlCoverArt = PISMO;}
            else if (artist == 'DALMATINKA') {var urlCoverArt = DALMATINKA;}
            else if (artist == 'KAZI MI DA SI JOS UVEK SAMA') {var urlCoverArt = KAZU_MI_DA_SI_JOS_UVEK_SAMA;}
            else if (artist == 'PARISKI LOKAL') {var urlCoverArt = PARISKI_LOKAL;}
            else if (artist == 'AJSA') {var urlCoverArt = AJSA;}
            else if (artist == 'ELIZABET') {var urlCoverArt = ELIZABET;}
            else if (artist == 'CUVAJ SE') {var urlCoverArt = CUVAJ_SE;}
            else if (artist == 'JUBI SAN VASU KCER') {var urlCoverArt = JUBI_SAN_VASU_KCER;}
            else if (artist == 'JEDNU MLADOST IMAM') {var urlCoverArt = JEDNU_MLADOST_IMAM;}
            else if (artist == 'HARMONIKA') {var urlCoverArt = HARMONIKA;}
            else if (artist == 'JUGOSLOVENKA') {var urlCoverArt = JUGOSLOVENKA;}
            else if (artist == 'RUSKA COKOLADA') {var urlCoverArt = RUSKA_COKOLADA;}
            else if (artist == 'JEDINO MOJE') {var urlCoverArt = JEDINO_MOJE;}
            else if (artist == 'DOK GITARA SVIRA') {var urlCoverArt = DOK_GITARA_SVIRA;}
        else {var urlCoverArt = DEFAULT_COVER_ART;}

        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {var coverArt = document.getElementById('currentCoverArt');var coverBackground = document.getElementById('bgCover');
        if (this.readyState === 4 && this.status === 200) {    var data = JSON.parse(this.responseText);    var artworkUrl100 = (data.resultCount) ? data.results[0].artworkUrl100 : urlCoverArt;
            urlCoverArt = (artworkUrl100 != urlCoverArt) ? artworkUrl100.replace('100x100bb', '512x512bb') : urlCoverArt;    var urlCoverArt96 = (artworkUrl100 != urlCoverArt) ? urlCoverArt.replace('512x512bb', '96x96bb') : urlCoverArt;    var urlCoverArt128 = (artworkUrl100 != urlCoverArt) ? urlCoverArt.replace('512x512bb', '128x128bb') : urlCoverArt;    var urlCoverArt192 = (artworkUrl100 != urlCoverArt) ? urlCoverArt.replace('512x512bb', '192x192bb') : urlCoverArt;    var urlCoverArt256 = (artworkUrl100 != urlCoverArt) ? urlCoverArt.replace('512x512bb', '256x256bb') : urlCoverArt;    var urlCoverArt384 = (artworkUrl100 != urlCoverArt) ? urlCoverArt.replace('512x512bb', '384x384bb') : urlCoverArt;
            coverArt.style.backgroundImage = 'url(' + urlCoverArt + ')';    coverArt.className = 'animated bounceInLeft';
            coverBackground.style.backgroundImage = 'url(' + urlCoverArt + ')';
            setTimeout(function () {
                coverArt.className = '';
            }, 2000);
            if ('mediaSession' in navigator) {
                navigator.mediaSession.metadata = new MediaMetadata({
                    title: song,
                    artist: artist,
                    artwork: [{                
                        src: urlCoverArt96,                
                        sizes: '96x96',                
                        type: 'image/png'            
                    },            
                    {                
                        src: urlCoverArt128,                
                        sizes: '128x128',                
                        type: 'image/png'            
                    },            
                    {                
                        src: urlCoverArt192,                
                        sizes: '192x192',                
                        type: 'image/png'            
                    },            
                    {                
                        src: urlCoverArt256,                
                        sizes: '256x256',                
                        type: 'image/png'            
                    },            
                    {                
                        src: urlCoverArt384,                
                        sizes: '384x384',                
                        type: 'image/png'            
                    },            
                    {                
                        src: urlCoverArt,                
                        sizes: '512x512',                
                        type: 'image/png'            
                    }            
                ]        
            });    
        }}}
                xhttp.open('GET', 'https://itunes.apple.com/search?term=' + artist + ' ' + song + '&media=music&limit=1', true); // претражување на слики од iTunes
                xhttp.send();
            }

    this.changeVolumeIndicator = function (volume) {
        document.getElementById('volIndicator').innerHTML = volume;

        if (typeof (Storage) !== 'undefined') {localStorage.setItem('volume', volume);}
    }

    this.setVolume = function () {
        if (typeof (Storage) !== 'undefined') {var volumeLocalStorage = (!localStorage.getItem('volume')) ? 80 : localStorage.getItem('volume');document.getElementById('volume').value = volumeLocalStorage;document.getElementById('volIndicator').innerHTML = volumeLocalStorage;}
    }

    this.refreshLyric = function (currentSong, currentArtist) {
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {if (this.readyState === 4 && this.status === 200) {    var data = JSON.parse(this.responseText);
    var openLyric = document.getElementsByClassName('lyrics')[0];
    if (data.type === 'exact' || data.type === 'aprox') {        
        var lyric = data.mus[0].text;
        document.getElementById('lyric').innerHTML = lyric.replace(/\n/g, '<br />');        
        openLyric.style.opacity = "1";        
        openLyric.setAttribute('data-toggle', 'modal');    
        } 
    else {        
        openLyric.style.opacity = "0.3";        
        openLyric.removeAttribute('data-toggle');
        var modalLyric = document.getElementById('modalLyrics');        
        modalLyric.style.display = "none";        
        modalLyric.setAttribute('aria-hidden', 'true');
                (document.getElementsByClassName('modal-backdrop')[0]) ? document.getElementsByClassName('modal-backdrop')[0].remove() : '';    
            }} 
            else {    
                document.getElementsByClassName('lyrics')[0].style.opacity = "0.3";    
                document.getElementsByClassName('lyrics')[0].removeAttribute('data-toggle');}}
        xhttp.open('GET', 'https://api.vagalume.com.br/search.php?apikey=' + API_KEY + '&art=' + currentArtist + '&mus=' + currentSong.toLowerCase(), true); // Од каде да ги чита текстовите за песните
        xhttp.send()
    }
}

var audio = new Audio(URL_STREAMING2);

function Player() {
    this.play = function () {
        audio.play();

        var defaultVolume = document.getElementById('volume').value;

        if (typeof (Storage) !== 'undefined') {if (localStorage.getItem('volume') !== null) {    audio.volume = intToDecimal(localStorage.getItem('volume'));} else {    audio.volume = intToDecimal(defaultVolume);}} else {audio.volume = intToDecimal(defaultVolume);}
        document.getElementById('volIndicator').innerHTML = defaultVolume;
    };

    this.pause = function () {
        audio.pause();
    };
}

audio.onplay = function () {
    var botao = document.getElementById('playerButton');

    if (botao.className === 'fa fa-play') {
        botao.className = 'fa fa-pause';
    }
}

audio.onpause = function () {
    var botao = document.getElementById('playerButton');

    if (botao.className === 'fa fa-pause') {
        botao.className = 'fa fa-play';
    }
}

audio.onvolumechange = function () {
    if (audio.volume > 0) {
        audio.muted = false;
    }
}

audio.onerror = function () {
    var confirmacao = confirm('Грешка при комуникацијата со серверот. \nКликни ОК и продолжи пак.');

    if (confirmacao) {
        window.location.reload();
    }
}

document.getElementById('volume').oninput = function () {
    audio.volume = intToDecimal(this.value);

    var page = new Page();
    page.changeVolumeIndicator(this.value);
}

function togglePlay() {
    if (!audio.paused) {
        audio.pause();
    } else {
        audio.load();
        audio.play();
    }
}

function volumeUp() {
    var vol = audio.volume;
    if (audio) {
        if (audio.volume >= 0 && audio.volume < 1) {audio.volume = (vol + .01).toFixed(2);}
    }
}

function volumeDown() {
    var vol = audio.volume;
    if (audio) {
        if (audio.volume >= 0.01 && audio.volume <= 1) {audio.volume = (vol - .01).toFixed(2);}
    }
}

function mute() {
    if (!audio.muted) {
        document.getElementById('volIndicator').innerHTML = 0;
        document.getElementById('volume').value = 0;
        audio.volume = 0;
        audio.muted = true;
    } else {
        var localVolume = localStorage.getItem('volume');
        document.getElementById('volIndicator').innerHTML = localVolume;
        document.getElementById('volume').value = localVolume;
        audio.volume = intToDecimal(localVolume);
        audio.muted = false;
    }
}

function getStreamingData() {
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function () {

        if (this.readyState === 4 && this.status === 200) {
if (this.response.length === 0) {    console.log('%cdebug', 'font-size: 22px')}
var data = JSON.parse(this.responseText);
var page = new Page();
var currentSongElement = document.getElementById('currentSong');
let song = data.currentSong.replace(/&apos;/g, '\'');currentSong = song.replace(/&amp;/g, '&');
let artist = data.currentArtist.replace(/&apos;/g, '\'');currentArtist = artist.replace(/&amp;/g, '&');
document.title = currentSong + ' - ' + currentArtist + ' | ' + RADIO_NAME;
if (currentSongElement.innerText !== song.trim()) {    page.refreshCover(currentSong, currentArtist);    page.refreshCurrentSong(currentSong, currentArtist);    page.refreshLyric(currentSong, currentArtist);
    for (var i = 0; i < 2; i++) {        page.refreshHistoric(data.songHistory[i], i);    }}}
    };

    var d = new Date();

    xhttp.open('GET', 'api.php?url=' + URL_STREAMING + '&streamtype=' + STREAMING_TYPE + '&historic=' + HISTORIC + '&next=' + NEXT_SONG + '&t=' + d.getTime(), true);
    xhttp.send();
}

document.addEventListener('keydown', function (k) {
    var k = k || window.event;
    var key = k.keyCode || k.which;

    var slideVolume = document.getElementById('volume');

    var page = new Page();

    switch (key) {
        // Arrow up
        case 38:volumeUp();slideVolume.value = decimalToInt(audio.volume);page.changeVolumeIndicator(decimalToInt(audio.volume));break;
        // Arrow down
        case 40:volumeDown();slideVolume.value = decimalToInt(audio.volume);page.changeVolumeIndicator(decimalToInt(audio.volume));break;
        // Spacebar
        case 32:togglePlay();break;
        // P
        case 80:togglePlay();break;
        // M
        case 77:mute();break;
        // 0
        case 48:audio.volume = 0;slideVolume.value = 0;page.changeVolumeIndicator(0);break;
        // 0 numeric keyboard
        case 96:audio.volume = 0;slideVolume.value = 0;page.changeVolumeIndicator(0);break;
        // 1
        case 49:audio.volume = .1;slideVolume.value = 10;page.changeVolumeIndicator(10);break;
        // 1 numeric key
        case 97:audio.volume = .1;slideVolume.value = 10;page.changeVolumeIndicator(10);break;
        // 2
        case 50:audio.volume = .2;slideVolume.value = 20;page.changeVolumeIndicator(20);break;
        // 2 numeric key
        case 98:audio.volume = .2;slideVolume.value = 20;page.changeVolumeIndicator(20);break;
        // 3
        case 51:audio.volume = .3;slideVolume.value = 30;page.changeVolumeIndicator(30);break;
        // 3 numeric key
        case 99:audio.volume = .3;slideVolume.value = 30;page.changeVolumeIndicator(30);break;
        // 4
        case 52:audio.volume = .4;slideVolume.value = 40;page.changeVolumeIndicator(40);break;
        // 4 numeric key
        case 100:audio.volume = .4;slideVolume.value = 40;page.changeVolumeIndicator(40);break;
        // 5
        case 53:audio.volume = .5;slideVolume.value = 50;page.changeVolumeIndicator(50);break;
        // 5 numeric key
        case 101:audio.volume = .5;slideVolume.value = 50;page.changeVolumeIndicator(50);break;
        // 6 
        case 54:audio.volume = .6;slideVolume.value = 60;page.changeVolumeIndicator(60);break;
        // 6 numeric key
        case 102:audio.volume = .6;slideVolume.value = 60;page.changeVolumeIndicator(60);break;
        // 7
        case 55:audio.volume = .7;slideVolume.value = 70;page.changeVolumeIndicator(70);break;
        // 7 numeric key
        case 103:audio.volume = .7;slideVolume.value = 70;page.changeVolumeIndicator(70);break;
        // 8
        case 56:audio.volume = .8;slideVolume.value = 80;page.changeVolumeIndicator(80);break;
        // 8 numeric key
        case 104:audio.volume = .8;slideVolume.value = 80;page.changeVolumeIndicator(80);break;
        // 9
        case 57:audio.volume = .9;slideVolume.value = 90;page.changeVolumeIndicator(90);break;
        // 9 numeric key
        case 105:audio.volume = .9;slideVolume.value = 90;page.changeVolumeIndicator(90);break;
    }
});

function intToDecimal(vol) {
    return vol / 100;
}

function decimalToInt(vol) {
    return vol * 100;
}

// Движечки елементи
//var textWrapper = document.querySelector('.ml7 .letters');
//textWrapper.innerHTML = textWrapper.textContent.replace(/\S/g, "<span class='letter'>$&</span>");

//anime.timeline({ loop: true })
//    .add({
//        targets: '.ml7 .letter',
//        translateY: ["1.1em", 0],
  //      translateX: ["0.55em", 0],
    //    translateZ: 0,
      //  rotateZ: [180, 0],
        //duration: 2550, // колку да врти на почеток
        //easing: "easeOutExpo",
        //delay: (el, i) => 50 * i
    //}).add({
    //    targets: '.ml7',
    //    opacity: 0,
    //    duration: 20000,
    //    easing: "easeOutExpo",
    //    delay: 1000
    //});