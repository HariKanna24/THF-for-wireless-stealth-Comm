function simulate_temporal_dynamic_hopping()
    shared_path = '/MATLAB Drive/flask_hopping_project/shared_data';
    config_path = fullfile(shared_path, 'hopping_config.json');
    msg_file = fullfile(shared_path, 'text_message.txt');

    % === Default Settings ===
    base_freq = 1000;
    interval = 1;

    if isfile(config_path)
        raw = fileread(config_path);
        config = jsondecode(raw);
        base_freq = config.start_freq;
        interval = config.hop_interval;
    end

    % === Simulation Flags ===
    flag_file = fullfile(shared_path, 'simulation_flags.json');
    simulate_jamming = false;
    simulate_eavesdropping = false;
    if isfile(flag_file)
        flags = jsondecode(fileread(flag_file));
        if isfield(flags, 'simulate_jamming')
            simulate_jamming = flags.simulate_jamming;
        end
        if isfield(flags, 'simulate_eavesdropping')
            simulate_eavesdropping = flags.simulate_eavesdropping;
        end
    end

    % === Extract Data From Input ===
    tfh_log = zeros(1,10);
    dch_log = zeros(1,10);
    jammed = false(1,10);
    eaves_indices = [];

    if isfile(msg_file)
        fid = fopen(msg_file, 'rb');
        enc = fread(fid, '*uint8')'; fclose(fid);
        key = 'eceproject2025';
        dec = bitxor(enc, uint8(key(mod(0:length(enc)-1, length(key))+1)));
        message = double(dec);
    else
        message = randi([65 122], 1, 10);  % fallback random
    end

    % === TFH Pattern Based on ASCII Spectrum ===
    for i = 1:10
        if i <= length(message)
            tfh_log(i) = base_freq + mod(message(i)*i, 250) - 125;
        else
            tfh_log(i) = base_freq + randi([-100, 100]);
        end
    end

    % === DCH Pattern Based on TFH + More Offset ===
    for i = 1:10
        time_str = datestr(datetime('now', 'TimeZone', 'Asia/Kolkata'), 'HH:MM:SS');

        if simulate_eavesdropping && rand < 0.4
            fprintf("👀 Eavesdropping Activity on TFH: %d Hz | Time: %s\n", tfh_log(i), time_str);
            eaves_indices(end+1) = i;
        else
            fprintf("⏱️ TFH: %d Hz | Time: %s\n", tfh_log(i), time_str);
        end

        if simulate_jamming && rand < 0.5
            dch_log(i) = tfh_log(i) + randi([300, 600]);
            jammed(i) = true;
            fprintf("⚠️ Jamming Detected! Switched to DCH: %d Hz\n", dch_log(i));
        else
            dch_log(i) = tfh_log(i) + randi([-200, 200]);  % bigger variation
        end

        pause(interval);
    end

    % === Save for GUI ===
    save(fullfile(shared_path, 'tfh_dch_log.mat'), 'tfh_log', 'dch_log', 'jammed', 'eaves_indices');
end
