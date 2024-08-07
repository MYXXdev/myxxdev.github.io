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
                      bottom: 60px; /* Adjusted from 100px to 60px */
                      right: 20px;
          `
          : `
                      bottom: 60px; /* Adjusted from 100px to 60px */
                      left: 20px;
          `
        }
          max-height: calc(100vh - 60px - 20px); /* Adjusted max-height accordingly */
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
  this.iframe.style.zIndex = "2147483646";
  document.querySelector("body").appendChild(this.iframe);

  scopeDomContainer.querySelectorAll(".podinbox__floating-btn").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      if (document.body.classList.contains("podinbox__modal--opened")) {
        document.body.classList.remove("podinbox__modal--opened");
      } else {
        document.body.classList.add("podinbox__modal--opened");
      }
    });
  });

  return {
    scopeDom,
  };
};
