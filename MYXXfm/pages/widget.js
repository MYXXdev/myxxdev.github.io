if (typeof podinboxFloatingWidgets_implemented === "undefined") {
  var podinboxFloatingWidgets_implemented = [];
}
(function() {
  const WidgetClass = function({
    base = 'fanlist',
    floatingWidget = false
  }) {
    const [PODINBOX_SHOW_WIDGET_INLINE, PODINBOX_SHOW_WIDGET_POPUP] = [
      `.${base}-inline-widget`,
      `${base}-popup`,
    ];
  
    const podcastIcon = `<svg aria-hidden="true" focusable="false" data-prefix="fas" data-icon="microphone-alt" class="svg-inline--fa fa-microphone-alt fa-w-11 sc-gGLxEB gnzyjD" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 352 512" css="font-size: 24px;"><path fill="currentColor" d="M336 192h-16c-8.84 0-16 7.16-16 16v48c0 74.8-64.49 134.82-140.79 127.38C96.71 376.89 48 317.11 48 250.3V208c0-8.84-7.16-16-16-16H16c-8.84 0-16 7.16-16 16v40.16c0 89.64 63.97 169.55 152 181.69V464H96c-8.84 0-16 7.16-16 16v16c0 8.84 7.16 16 16 16h160c8.84 0 16-7.16 16-16v-16c0-8.84-7.16-16-16-16h-56v-33.77C285.71 418.47 352 344.9 352 256v-48c0-8.84-7.16-16-16-16zM176 352c53.02 0 96-42.98 96-96h-85.33c-5.89 0-10.67-3.58-10.67-8v-16c0-4.42 4.78-8 10.67-8H272v-32h-85.33c-5.89 0-10.67-3.58-10.67-8v-16c0-4.42 4.78-8 10.67-8H272v-32h-85.33c-5.89 0-10.67-3.58-10.67-8v-16c0-4.42 4.78-8 10.67-8H272c0-53.02-42.98-96-96-96S80 42.98 80 96v160c0 53.02 42.98 96 96 96z"></path></svg>`;
    const podinboxIcon = `<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 670 670" width="20px" height="20px"><defs></defs><g id="Icon_-_Round_-_White_Transparent_Play" stroke-opacity="1" fill-opacity="1" stroke="none" stroke-dasharray="none" fill="none"><title>Icon - Round - White Transparent Play</title><g id="Icon_-_Round_-_White_Transparent_Play_Layer_1"><title>Layer 1</title><g id="Graphic_31"><path d="M 584.10324 2.228243 L 85.35324 2.228243 C 39.50461 2.228243 2.228243 39.50243 2.228243 85.34838 L 2.228243 459.389 C 2.228243 505.235 39.50461 542.50916 85.35324 542.50916 L 210.04074 542.50916 L 210.04074 651.60435 C 210.04074 664.3321 224.58762 671.735 234.84836 664.20224 L 397.072 542.50916 L 584.10324 542.50916 C 629.9519 542.50916 667.22824 505.235 667.22824 459.389 L 667.22824 85.34838 C 667.22824 39.50243 629.9519 2.228243 584.10324 2.228243 Z M 286.74908 202.85006 L 286.74908 202.85006 C 286.74908 202.3398 286.87922 201.83798 287.1272 201.39203 C 287.93246 199.94402 289.7591 199.42295 291.2071 200.2282 L 417.2879 270.34215 C 417.7779 270.6146 418.1817 271.01892 418.45356 271.50922 C 419.257 272.95823 418.7337 274.7842 417.2847 275.58767 L 291.20386 345.4977 C 290.7587 345.74454 290.25808 345.87405 289.74908 345.87405 C 288.09222 345.87405 286.74908 344.5309 286.74908 342.87405 Z" fill="currentColor"></path></g></g></g></svg>`;
    const closeIcon = `<svg xmlns="http://www.w3.org/2000/svg" style="width: 14px; height: 14px;"><path d="M13.707.293a.999.999 0 0 0-1.414 0L7 5.586 1.707.293A.999.999 0 1 0 .293 1.707L5.586 7 .293 12.293a.999.999 0 1 0 1.414 1.414L7 8.414l5.293 5.293a.997.997 0 0 0 1.414 0 .999.999 0 0 0 0-1.414L8.414 7l5.293-5.293a.999.999 0 0 0 0-1.414" fill="currentColor" fill-rule="evenodd"></path></svg>`;
  
    const PodinboxShowIframe = function (
      {
        uuid: showUUID,
        origin,
        isFloating = false,
        baseBottom = false,
      }) {
      const uuid = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(
        /[xy]/g,
        function(c) {
          var r = (Math.random() * 16) | 0,
            v = c === "x" ? r : (r & 0x3) | 0x8;
          return v.toString(16);
        }
      );
      const widgetID = `podinbox_show_widget_${showUUID}_${uuid}`;
      const link = `${origin}/${isFloating ? `floating-widget` : `widget`
        }/${showUUID}?widget_id=${widgetID}${baseBottom ? "&baseBottom=true" : ""}`;
      const iframe = document.createElement("iframe");
      iframe.frameBorder = 0;
      iframe.width = "100%";
      iframe.height = "0";
      iframe.allow = "camera *;microphone *";
      iframe.setAttribute("src", link);

      this.iframe = iframe;
      this.widgetID = widgetID;

      const resizeWidget = (height) => {
        iframe.height = `${height}px`;
      };

      const handleMounted = () => {
        this.onMounted && this.onMounted();
      };

      window.addEventListener(
        "message",
        (event) => {
          if (event.origin !== "https://fanlist.com" && event.origin !== origin) {
            return;
          }
          const { data } = event;
          if (data.widget_id !== widgetID) {
            return;
          }
          const { name, height } = data;
          switch (name) {
            case 'resize':
              resizeWidget(height);
              break;
            case 'mounted':
              handleMounted();
              break;
            default:
              break;
          }
        },
        false
      );
    };

    const PodinboxShowWidgetInline = function({ scopeDom, uuid, origin }) {
      const IframeHandler = new PodinboxShowIframe({ uuid, origin });
      scopeDom.appendChild(IframeHandler.iframe);
      this.iframe = IframeHandler.iframe;
    };
    const PodinboxShowWidgetPopup = function({ scopeDom, uuid, origin }) {
      let everShowed = false;
      const modalLayout = document.createElement("div");
      modalLayout.innerHTML = `
              <div class="podinbox__modal-root">
                  <div class="podinbox__modal-mask"></div>
                  <div class="podinbox__modal-wrap" role="dialog">
                      <div class="podinbox__modal">
                          <div class="podinbox__modal-content"></div>
                      </div>
                  </div>
              </div>
          `;
      const modalMask = modalLayout.querySelector(".podinbox__modal-mask");
      const modalContent = modalLayout.querySelector(".podinbox__modal-content");
      const IframeHandler = new PodinboxShowIframe({ uuid, origin });
      this.iframe = IframeHandler.iframe;
      modalContent.appendChild(this.iframe);

      const showModal = () => {
        document.querySelector("body").appendChild(modalLayout);
        if (!everShowed) {
          everShowed = true;
        }
      };

      const hideModal = () => {
        document.querySelector("body").removeChild(modalLayout);
        this.iframe.height = "0";
      };
      const handleRootClick = (e) => {
        if (!modalContent.contains(e.target)) {
          hideModal();
        }
      };
      const addEvents = () => {
        scopeDom.addEventListener(`click`, showModal);
        modalLayout.addEventListener(`click`, handleRootClick);
      };

      addEvents();
    };

    function PodinboxShowWidgetFloating({ uuid, origin }) {
      let scopeDomContainer = null;
      let scopeDom = null;
      const [BOTTOM_RIGHT, BOTTOM_LEFT] = ["BOTTOM_RIGHT", "BOTTOM_LEFT"];
      const [PODCAST, AVATAR, VIDEO] = ["PODCAST", "AVATAR", "VIDEO"];

      const modalLayout = document.createElement("div");
      modalLayout.innerHTML = `
              <div class="podinbox__modal-floating-root">
                  <div class="podinbox__modal-content"></div>
              </div>
          `;
      const modalRoot = modalLayout.querySelector(
        ".podinbox__modal-floating-root"
      );
      const modalContent = modalLayout.querySelector(".podinbox__modal-content");

      const showModal = () => {
        modalRoot.classList.add("podinbox__modal--opened");
        scopeDom.classList.add("modal-opened");
      };

      const hideModal = () => {
        modalRoot.classList.remove("podinbox__modal--opened");
        scopeDom.classList.remove("modal-opened");
        this.iframe.contentWindow.postMessage(
          { name: "reset", widget_id: this.iframeHandler.widgetID },
          origin
        );
      };

      const renderAvatar = (avatarUrl) => {
        if (!avatarUrl) {
          return "";
        }
        return `
              <div class="widget-avatar" style="background-image: url('${avatarUrl}');"></div>
          `;
      };

      const renderVideo = (settings) => {
        return `
              <div class="widget-video">
                <video autoplay muted loop src="${settings.widget_video_url}" />
              </div>
          `;
      };

      const renderWidgetButton = async () => {
        const { settings } = await fetch(
          `${origin}/widget-settings?uuid=${uuid}&token=318a2d18a82e27ff278a26f78f07770183a87c1a6fb822a54a5015f`
        ).then((res) => res.json());

        const addWidgetStyle = () => {
          const style = document.createElement("style");
          style.innerHTML = `
                      .podinbox__floating-trigger-container {
                          border-radius: 30px;
                          box-shadow: rgb(0 0 0 / 10%) 0px 4px 7px;
                          position: fixed;
                          z-index: 2147483647;
                          height: 60px;
                          ${settings.floating_widget_display_option ===
              BOTTOM_RIGHT
              ? `bottom: 20px; right: 20px;`
              : `bottom: 20px; left: 20px;`
            }
                      }
                      .podinbox__floating-btn {
                          font-family: Lexend, Helvetica, Arial, sans-serif;
                          --color: ${settings.floating_widget_color};
                          --color-text: ${settings.floating_widget_text_color};
                          display: inline-flex;
                          align-items: center;
                          justify-content: center;
                          box-sizing: border-box;
                          height: 100%;
                          min-width: 60px;
                          ${[AVATAR, VIDEO].includes(
              settings.floating_widget_icon_type
            )
              ? settings.floating_widget_show_button_text
                ? `padding: 15px 20px;`
                : `padding: 0;`
              : `padding: 15px 20px;`
            }
                          border-radius: 30px;
                          position: relative;
                          color: var(--color-text);
                          text-transform: none;
                          font-size: 14px;
                          letter-spacing: 0.02em;
                          background-color: var(--color);
                          cursor: pointer;
                          font-size: 14px;
                          line-height: 1.5715;
                          z-index: 10;
                          white-space: pre;
                      }
                      .podinbox__floating-btn .podinbox__btn__inner {
                          height: 100%;
                          display: flex;
                          align-items: center;
                          justify-content: center;
                          gap: 10px;
                      }
                      .podinbox__floating-btn .podinbox__btn__inner .widget-avatar {
                          width: 80px;
                          height: 80px;
                          border-radius: 50%;
                          background-size: cover;
                          background-position: center;
                          background-color: white;
                          border: 4px solid var(--color);
                          position: relative;
                          z-index: 1;
                          ${settings.floating_widget_show_button_text
              ? `margin-left: -20px`
              : ``
            }
                      }
                      .podinbox__floating-btn .podinbox__btn__inner .video-container {
                        display: flex;
                      }
                      .podinbox__floating-btn .podinbox__btn__inner .widget-video {
                          display: flex;
                          width: 80px;
                          height: 80px;
                          position: relative;
                          z-index: 1;
                          border-radius: 50%;
                          background-size: cover;
                          background-position: center;
                          background-color: white;
                          border: 4px solid var(--color);
                          line-height: 0;
                          ${settings.floating_widget_show_button_text
              ? `margin-left: -20px`
              : ``
            }
                      }
                      .podinbox__floating-btn .podinbox__btn__inner .widget-video video {
                        display: block;
                        width: 100%;
                        height: 100%;
                        object-fit: cover;
                        object-position: center 30%;
                        border-radius: 50%;
                      }
                      .podinbox__floating-btn:before {
                          content: "";
                          display: block;
                          position: absolute;
                          top: 0;
                          right: 0;
                          bottom: 0;
                          left: 0;
                          background-color: black;
                          opacity: 0;
                          border-radius: 40px;
                      }
                      .podinbox__floating-btn:hover:before {
                          opacity: .1;
                      }
                      .podinbox__floating-btn svg {
                          font-size: 24px;
                          height: 1em;
                      }
                      .podinbox__floating-btn span {
                          display: inline-block;
                      }
                      .podinbox__floating-trigger-btn .podinbox__btn__inner {
                          opacity: 1;
                          transform: scale(1);
                          transition: opacity 80ms linear 0s, transform 160ms linear 0s;
                      }
                      .podinbox__floating-trigger-container.modal-opened .podinbox__floating-trigger-btn {
                          position: absolute;
                          top: 0;
                          right: 0;
                          z-index: 0;
                          visibility: hidden;
                      }
                      .podinbox__floating-trigger-container.modal-opened .podinbox__floating-trigger-btn .podinbox__btn__inner {
                          transform: scale(0.8);
                          opacity: 0;
                      }
                      .podinbox__floating-close-btn {
                          border-radius: 50%;
                          transform: rotate(0deg) scale(1);
                          transition: opacity 80ms linear 0s, transform 160ms linear 0s;
                          opacity: 1;
                      }
                      .podinbox__floating-trigger-container:not(.modal-opened) .podinbox__floating-close-btn{
                          position: absolute;
                          top: 0;
                          right: 0;
                          z-index: 0;
                          opacity: 0;
                          transform: rotate(30deg) scale(1);
                      }
                      .podinbox__modal-floating-root {
                          display: flex;
                          flex-direction: column-reverse;
                          position: fixed;
                          z-index: 2147483647;
                          ${settings.floating_widget_display_option ===
              BOTTOM_RIGHT
              ? `
                              bottom: 100px;
                              right: 20px;
                          `
              : `
                              bottom: 100px;
                              left: 20px;
                          `
            }
                          max-height: calc(100vh - 100px - 20px);
                          width: 350px;
                          max-width: calc(100vw - 20px * 2);
                          border-radius: 8px;
                          box-shadow: rgb(0 0 0 / 5%) 0px 0px 0px 1px, rgb(0 0 0 / 15%) 0px 5px 30px 0px, rgb(0 0 0 / 5%) 0px 3px 3px 0px;
                          overflow: auto;
                          transform: translateY(20px);

                          opacity: 0;
                          pointer-events: none;
                          transition: opacity 250ms ease-out 0s, transform 250ms ease-out 0s;
                      }

                      .podinbox__modal-floating-root.podinbox__modal--opened {
                          opacity: 1;
                          pointer-events: auto;
                          transform: translateY(0px);
                      }

                      .podinbox__modal-floating-root .podinbox__modal-content {
                          width: 100%;
                          max-width: 100%;
                          line-height: 0;
                      }
                      .podinbox__modal-floating-root .podinbox__modal-content iframe {
                      }
                  `;
          document.getElementsByTagName("head")[0].appendChild(style);
        };
        addWidgetStyle();
        document.querySelector("body").appendChild(modalLayout);
        scopeDomContainer = document.createElement("div");
        scopeDomContainer.innerHTML = `
                  <div class="podinbox__floating-trigger-container">
                      <div class="podinbox__floating-trigger-btn podinbox__floating-btn">
                          <div class="podinbox__btn__inner">
                              ${settings.floating_widget_icon_type === VIDEO
            ? `<div class="video-container"></div>`
            : settings.floating_widget_icon_type === AVATAR
              ? renderAvatar(settings.owner_avatar_url)
              : settings.floating_widget_icon_type === PODCAST
                ? podcastIcon
                : podinboxIcon
          }
                              ${settings.floating_widget_show_button_text
            ? `<span> MYXX Mic</span>`
            : ``
          }
                          </div>
                      </div>
                      <div class="podinbox__floating-close-btn podinbox__floating-btn">
                          <div class="podinbox__btn__inner">
                              ${closeIcon}
                          </div>
                      </div>
                  </div>
              `;
        scopeDom = scopeDomContainer.querySelector(
          ".podinbox__floating-trigger-container"
        );

        const FloatIframeHandler = new PodinboxShowIframe({
          uuid,
          origin,
          isFloating: true,
          baseBottom: true,
        });
        this.iframe = FloatIframeHandler.iframe;
        this.iframeHandler = FloatIframeHandler;
        modalContent.appendChild(this.iframe);

        const addEvents = () => {
          scopeDom
            .querySelector(".podinbox__floating-trigger-btn")
            .addEventListener(`click`, showModal);
          scopeDom
            .querySelector(".podinbox__floating-close-btn")
            .addEventListener(`click`, hideModal);

          FloatIframeHandler.onMounted = () => {
            document.querySelector("body").appendChild(scopeDomContainer);
            if (settings.floating_widget_icon_type === VIDEO) {
              scopeDomContainer.querySelector(".video-container").innerHTML =
                renderVideo(settings);
            }
          };

          window.addEventListener(
            "message",
            (event) => {
              if (event.origin !== origin) {
                return;
              }
              const { data } = event;
              if (data.widget_id !== FloatIframeHandler.widgetID) {
                return;
              }
              const { name } = data;
              switch (name) {
                case `close_popup`:
                  hideModal();
                  break;
                default:
                  break;
              }
            },
            false
          );
        };

        addEvents();
      };

      renderWidgetButton();
    }

    const addWidgetStyle = () => {
      const style = document.createElement("style");
      style.innerHTML = `
              ${PODINBOX_SHOW_WIDGET_INLINE} { line-height: 0; }

              .podinbox__modal-root {

              }
              .podinbox__modal-root .podinbox__modal-mask {
                  position: fixed;
                  top: 0;
                  left: 0;
                  bottom: 0;
                  right: 0;
                  z-index: 1000;
                  background-color: rgba(0, 0, 0, 0.45);
              }
              .podinbox__modal-root .podinbox__modal-wrap {
                  position: fixed;
                  top: 0;
                  right: 0;
                  bottom: 0;
                  left: 0;
                  overflow: auto;
                  outline: 0;
                  z-index: 2147483647;
              }
              .podinbox__modal-root .podinbox__modal-wrap .podinbox__modal {
                  box-sizing: border-box;
                  padding: 0;
                  color: rgba(0, 0, 0, 0.85);
                  font-size: 14px;
                  font-variant: tabular-nums;
                  line-height: 1.5715;
                  list-style: none;
                  font-feature-settings: 'tnum';
                  pointer-events: none;
                  position: relative;
                  top: 100px;
                  width: 650px;
                  max-width: calc(100vw - 32px);
                  margin: 0 auto;
                  padding-bottom: 24px;
              }
              .podinbox__modal-root .podinbox__modal-wrap .podinbox__modal-content{
                  max-width: 100%;
                  pointer-events: auto;
                  line-height: 0;
              }
          `;
      document.getElementsByTagName("head")[0].appendChild(style);
    };
    const podinboxOrigin = document
      .querySelector(`[${base}-origin]`)
      .getAttribute(`${base}-origin`);

    const podinboxShowInlineElements = document.querySelectorAll(
      `${PODINBOX_SHOW_WIDGET_INLINE}:not([${base}-widget--implemented])`
    );
    const podinboxShowPopupElements = document.querySelectorAll(
      `[${PODINBOX_SHOW_WIDGET_POPUP}]:not([${base}-widget--implemented])`
    );

    if (podinboxShowInlineElements.length || podinboxShowPopupElements.length) {
      addWidgetStyle();
    }
    podinboxShowInlineElements.forEach((showWidgetElement) => {
      const uuid = showWidgetElement.getAttribute("show");
      showWidgetElement.setAttribute(`${base}-widget--implemented`, "true");
      const ShowWidgetHandler = new PodinboxShowWidgetInline({
        scopeDom: showWidgetElement,
        origin: podinboxOrigin,
        uuid,
      });
    });
    podinboxShowPopupElements.forEach((showWidgetElement) => {
      const uuid = showWidgetElement.getAttribute(PODINBOX_SHOW_WIDGET_POPUP);
      showWidgetElement.setAttribute(`${base}-widget--implemented`, "true");
      const ShowWidgetHandler = new PodinboxShowWidgetPopup({
        scopeDom: showWidgetElement,
        uuid,
        origin: podinboxOrigin,
      });
    });
    if (
      typeof floatingWidget === "string" &&
      !podinboxFloatingWidgets_implemented.includes(floatingWidget)
    ) {
      podinboxFloatingWidgets_implemented.push(floatingWidget);
      const ShowWidgetHandler = new PodinboxShowWidgetFloating({
        uuid: floatingWidget,
        origin: podinboxOrigin,
      });
    }
  }
  if (document.querySelector(`[podinbox-origin]`)) {
    new WidgetClass({
      base: 'podinbox',
      ...(typeof podinboxFloatingWidget !== 'undefined' ? { floatingWidget: podinboxFloatingWidget } : {})
    });
  } else {
    new WidgetClass({
      base: 'fanlist',
      ...(typeof fanlistFloatingWidget !== 'undefined' ? { floatingWidget: fanlistFloatingWidget } : {})
    });
  }
})();