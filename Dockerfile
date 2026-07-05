FROM ubuntu:24.04 AS stage-server

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        lib32gcc-s1 \
        libsdl2-2.0-0 \
        libcurl4 \
        ca-certificates \
        curl \
        gettext-base \
        gosu \
        libgl1 \
        libxcursor1 \
        libxrandr2 \
        libxi6 \
        libxinerama1 \
        libxxf86vm1 \
        libasound2t64 \
        python3-minimal \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel -f ubuntu 2>/dev/null || true \
    && groupadd -g 1000 steam \
    && useradd -m -u 1000 -g steam -s /bin/bash steam

WORKDIR /server

EXPOSE 26900-26903/udp 26900-26903/tcp 8080/tcp 8081/tcp

RUN mkdir -p /data \
    && chown -R steam:steam /data

# T5: Install SteamCMD and download 7 Days to Die Dedicated Server v2.6
RUN mkdir -p /opt/steamcmd \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -o /tmp/steamcmd_linux.tar.gz \
    && tar -xzf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd \
    && rm -f /tmp/steamcmd_linux.tar.gz \
    && printf '%s\n' '#!/bin/bash' 'exec /opt/steamcmd/steamcmd.sh "$@"' > /usr/local/bin/steamcmd \
    && chmod +x /usr/local/bin/steamcmd \
    && steamcmd \
        +@sSteamCmdForcePlatformType linux \
        +force_install_dir /server \
        +login anonymous \
        +app_update 294420 -beta v2.6 validate \
        +quit \
    && rm -rf /server/Package /root/Steam /root/.steam \
    && chown -R steam:steam /server \
    && chmod -R u+rwX /server

# T7: COPY mod groups into /server/Mods/
# Requires BuildKit and an additional build context pointing at /tmp/rebirth-groups:
#   docker build --target stage-mods --build-context mods=/tmp/rebirth-groups ...
FROM stage-server AS stage-mods
COPY --from=mods --chown=steam:steam mods-group-0/ /server/Mods/
COPY --from=mods --chown=steam:steam mods-group-1/ /server/Mods/
COPY --from=mods --chown=steam:steam mods-group-2/ /server/Mods/
COPY --from=mods --chown=steam:steam mods-group-3/ /server/Mods/
# The Rebirth archive does not ship ModInfo.xml in zz_REBIRTH__Core_2_0. 7DTD v2.6
# ignores folders without one, so generate a V2-format descriptor so its
# Config/items.xml loads alongside the other Rebirth mods.
RUN <<EOF
set -e
MISSING_MOD="/server/Mods/zz_REBIRTH__Core_2_0"
if [ -d "$MISSING_MOD" ] && [ ! -f "$MISSING_MOD/ModInfo.xml" ]; then
    cat > "$MISSING_MOD/ModInfo.xml" <<'MODINFO'
<?xml version="1.0" encoding="UTF-8" ?>
<xml>
    <Name value="zz_REBIRTH__Core_2_0" />
    <DisplayName value="zz_REBIRTH__Core_2_0" />
    <Description value="Rebirth Core 2.0 config overrides" />
    <Author value="Rebirth" />
    <Website value="" />
    <Version value="1.0.0" />
</xml>
MODINFO
fi
chown -R steam:steam /server/Mods
chmod -R u+rwX /server/Mods
EOF

# T8: COPY entrypoint.sh and set ENTRYPOINT
FROM stage-mods
COPY serverconfig.xml.template /server/serverconfig.xml.template
COPY entrypoint.sh /server/entrypoint.sh
RUN chmod +x /server/entrypoint.sh
ENTRYPOINT ["/server/entrypoint.sh"]

# T9: Runtime user is handled by entrypoint.sh via gosu; do NOT set USER here.
# The container starts as root to fix /data ownership, then drops to steam.
