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

          .podinbox__modal-floating-root {
              display: flex;
              flex-direction: column-reverse;
              position: fixed;
              z-index: 2147483647;
              ${settings.floating_widget_display_option ===
              BOTTOM_RIGHT
              ? `
                  bottom: 150px;  /* Adjust this value */
                  right: 20px;
              `
              : `
                  bottom: 150px;  /* Adjust this value */
                  left: 20px;
              `
            }
              max-height: calc(100vh - 150px - 20px); /* Adjust this value */
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
  const modalRoot = modalLayout.querySelector(".podinbox__modal-floating-root");
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
              justify-content: center;
              align-items: center;
              width: 80px;
              height: 80px;
              border-radius: 50%;
              background: var(--color);
              box-shadow: 0px 0px 5px 0px rgba(0, 0, 0, 0.2);
          }
          .podinbox__floating-btn .podinbox__btn__inner .widget-video video {
              width: 100%;
              height: 100%;
              border-radius: 50%;
              object-fit: cover;
          }
      `;
      document.getElementsByTagName("head")[0].appendChild(style);
    };

    addWidgetStyle();

    const floatingButton = document.createElement("div");
    floatingButton.className = "podinbox__floating-trigger-container";
    floatingButton.innerHTML = `
          <div class="podinbox__floating-btn">
              <div class="podinbox__btn__inner">
                  ${settings.floating_widget_icon_type === AVATAR
                    ? renderAvatar(settings.floating_widget_avatar_url)
                    : settings.floating_widget_icon_type === VIDEO
                      ? renderVideo(settings)
                      : ""
                  }
                  ${settings.floating_widget_show_button_text
                    ? `<span class="podinbox__btn__text">${settings.floating_widget_text}</span>`
                    : ""
                  }
              </div>
          </div>
      `;
    document.body.appendChild(floatingButton);

    scopeDom = floatingButton;
    scopeDomContainer = modalContent;
    scopeDom.addEventListener("click", () => {
      if (!scopeDom.classList.contains("modal-opened")) {
        showModal();
      } else {
        hideModal();
      }
    });
  };

  renderWidgetButton();
}

