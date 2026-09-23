
{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Enable Docker
  virtualisation.docker.enable = true;

  # Garbage collection
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly"; # Runs weekly garbage collection
      options = "--delete-generations +4"; # Keeps 4 configs
    };
  };

# Ensure the virtual keyboard kernel module is accessible to the uinput group
services.udev.extraRules = ''
  KERNEL=="uinput", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
'';

# Force load the uinput kernel module at boot
boot.kernelModules = [ "uinput" ];

# Enable Tailscale VPN
services.tailscale.enable = true;

  # Enable Bluetooth support
  hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
  settings = {
    General = {
      # Resolves the Xbox controller infinite pairing disconnect loop
      JustWorksRepairing = "always";
      Privacy = "device";
      };
      Policy = {
        AutoEnable = true;
      };
    }; 
  };

  # Enable XBox controller support
  hardware.xpadneo.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 4; # Keeps number of configs on boot screen to 4
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # This line is critical for Steam
  };

  hardware.amdgpu.opencl.enable = true;

  # Keep these enabled as well for Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Optional, for Steam Remote Play
    dedicatedServer.openFirewall = true; # Optional, for Source games
  };


  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the Niri scrolling window manager.
  programs.niri.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # Use the WirePlumber session manager
    #wireplumber.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."pharmerhulstein" = {
    isNormalUser = true;
    description = "Chris Hulstein";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" "docker" ];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [
    noctalia # Desktop shell
    ghostty # Terminal emulator
    fastfetch # Terminal make pretty
    nwg-displays # Display manager for niri
    kdePackages.bluedevil # Need this for KDE Plasma Bluetooth management
    xwayland-satellite # For Steam and X11 dependent display
    neovim
    wget
    godot
    aseprite
    yazi
    btop
    git
    libreoffice
    wtype
    vulkan-tools
    pandoc
    kubectl
    kubernetes-helm
    (llama-cpp.override { vulkanSupport = true; rocmSupport = false; }) # Vulkan build for benchmarking vs Ollama
    nvtopPackages.amd # Live GPU/VRAM monitor
    amdgpu_top # Detailed AMD GPU stats
    (python3.withPackages (ps: [ ps.trafilatura ps.markitdown ])) # URL-to-md and PDF-to-md converters (merged to fix collision)
  ];

  # Set default editor to NeoVim
  #environment.variables.EDITOR = "neovim";


  # Enable Ollama and GPU Acceleration
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "12.0.1";
    host = "127.0.0.1"; # Localhost only; remote access goes through tailscale serve -> Open WebUI
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1"; # Required for KV cache quantization
      OLLAMA_KV_CACHE_TYPE = "q8_0"; # Roughly halves context memory
      OLLAMA_NUM_PARALLEL = "1"; # Single user: don't reserve a second context slot
      OLLAMA_MAX_LOADED_MODELS = "2"; # Chat model + embedding model can coexist for RAG
      OLLAMA_CONTEXT_LENGTH = "16384"; # Drop to 12288 or 8192 if `ollama ps` shows CPU use
      OLLAMA_KEEP_ALIVE = "15m"; # Unloads idle models to free VRAM for gaming
    };
    loadModels = [
      "qwen3:14b"
      "hf.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S"
      "gpt-oss:20b"
      "nomic-embed-text:latest"
    ];
    syncModels = false; # Prevents removal of the custom Qwen model used by AnythingLLM
  };

  # Enable a local, private search engine backend
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    environmentFile = "/var/lib/searx/secrets.env";
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        secret_key = "@SEARX_SECRET_KEY@";
      };
      search = {
        safe_search = 1;
        formats = [ "html" "json" ];
      };
      engines = [
        { name = "brave"; disabled = true; }
        { name = "duckduckgo"; disabled = true; }
        { name = "startpage"; disabled = true; }
        { name = "wikidata"; disabled = true; }
      ];
    };
  };

  # WebUI for Ollama
  services.open-webui = {
    enable = true;
    port = 8080;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      VECTOR_DB = "chroma";
      RAG_EMBEDDING_ENGINE = "ollama";
      RAG_OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      RAG_EMBEDDING_MODEL = "nomic-embed-text:latest";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";

      # WEB SEARCH CONFIGURATION: points directly to your local SearXNG service
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8888/search?q=<query>";
      ENABLE_KB_EXEC = "True";
    };
  };

  # AnythingLLM Install via Docker
  virtualisation.oci-containers = {
    backend = "docker";
    containers.anythingllm = {
      image = "mintplexlabs/anythingllm:latest";
      volumes = [ 
        "/var/lib/anythingllm:/app/server/storage" 
        "/var/lib/anythingllm/.env:/app/server/.env"
      ];
      environment = {
        STORAGE_DIR = "/app/server/storage";
        COLLECTOR_PORT = "8889";
      };
      extraOptions = [
        "--network=host"    # lets the container reach Ollama at 127.0.0.1:11434 directly
        "--cap-add=SYS_ADMIN"  # required by AnythingLLM per their own setup docs
      ];
    };
  };

  # Part of Anything LLM/Docker: Make sure the persistent storage folder exists with sane permissions
  # before the container tries to write to it
  systemd.tmpfiles.rules = [
    "d /var/lib/anythingllm 0755 1000 1000 -"
    "f /var/lib/anythingllm/.env 0644 1000 1000 -"
  ];

  # Systemd configuration to resolve file limits and GPU access
  systemd.services.ollama.serviceConfig.LimitNOFILE = 65536;
  systemd.services.ollama.serviceConfig.SupplementaryGroups = [ "render" "video" ];

  systemd.services.open-webui.serviceConfig.LimitNOFILE = 65536;
  systemd.services.open-webui.serviceConfig.TimeoutStartSec = "300";


  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
   ];

  # Place the bash config anywhere inside the main braces
  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      fastfetch
    '';
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?
}
