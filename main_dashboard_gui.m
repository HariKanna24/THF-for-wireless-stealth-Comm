function main_dashboard_gui
fig = uifigure('Name', '📡 Wireless Comm Dashboard', 'Position', [100 100 1350 620]);

% === Title and Clock ===
uilabel(fig, 'Text', '📡 Frequency Hopping Wireless Comm Dashboard', ...
    'FontSize', 18, 'FontWeight', 'bold', 'Position', [380 570 600 30]);
lblClock = uilabel(fig, 'Text', '', 'FontSize', 14, 'FontWeight', 'bold', ...
    'Position', [1100 570 200 30], 'HorizontalAlignment', 'right');

% === Clock Timer (IST) ===
clockTimer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
    'TimerFcn', @(~,~) updateClock());
start(clockTimer);
updateClock();


function safeSync()
    if exist('txtLog', 'var') && isvalid(txtLog)
        autoGitHubSync();
    end
end



% === Tabs ===
tabs = uitabgroup(fig, 'Position', [30 70 1280 460]);
tabTFH = uitab(tabs, 'Title', '📡 TFH Graph');
tabDCH = uitab(tabs, 'Title', '🔁 DCH Graph');
tabMetrics = uitab(tabs, 'Title', '📈 Metrics');
tabLog = uitab(tabs, 'Title', '📜 Logs');

axTFH = uiaxes(tabTFH, 'Position', [50 50 1150 350]); grid(axTFH, 'on');
axDCH = uiaxes(tabDCH, 'Position', [50 50 1150 350]); grid(axDCH, 'on');
axMetrics = uiaxes(tabMetrics, 'Position', [50 50 1150 350]); grid(axMetrics, 'on');
txtLog = uitextarea(tabLog, 'Position', [40 30 1180 400], 'Editable', 'off', 'FontName', 'Consolas');
% === Auto GitHub Sync Timer (start AFTER txtLog is created) ===
syncTimer = timer('ExecutionMode', 'fixedRate', 'Period', 20, ...
    'TimerFcn', @(~,~) safeSync());

% Start it at the end after UI is initialized
start(syncTimer);

% === Buttons ===
uibutton(fig, 'Text', '📥 Download', 'Position', [30 540 130 30], ...
    'ButtonPushedFcn', @(~,~) downloadData());
uibutton(fig, 'Text', '🔓 Decrypt & Run', 'Position', [170 540 130 30], ...
    'ButtonPushedFcn', @(~,~) receiveAndDecrypt());
uibutton(fig, 'Text', '🧾 Export PDF', 'Position', [310 540 130 30], ...
    'ButtonPushedFcn', @(~,~) exportPDF());
uibutton(fig, 'Text', '🎞️ Animate', 'Position', [450 540 130 30], ...
    'ButtonPushedFcn', @(~,~) animateGraphs());

% === GUI Exit Handling ===
fig.CloseRequestFcn = @(~,~) cleanup();

% === Functions ===
    function updateClock()
        t = datetime('now', 'TimeZone', 'Asia/Kolkata');
        lblClock.Text = datestr(t, 'dd-mmm-yyyy HH:MM:SS');
    end

    function logMsg(msg)
        txtLog.Value = [txtLog.Value; {char(msg)}];
        if numel(txtLog.Value) > 100
            txtLog.Value = txtLog.Value(end-99:end);
        end
    end

    function autoGitHubSync()
        try
            download_from_github;
            logMsg("🔁 Auto-synced from GitHub.");
        catch err
            logMsg("❌ GitHub sync failed: " + err.message);
        end
    end

    function downloadData()
        autoGitHubSync();
        logMsg("✅ Downloaded files from GitHub.");
    end

    function receiveAndDecrypt()
    downloadData();
    folder = '/MATLAB Drive/flask_hopping_project/shared_data';
    txtFile = fullfile(folder, 'text_message.txt');
    audioFile = fullfile(folder, 'uploaded_audio.wav');

    textLen = 10;  % default
    audioDur = 2.0; % default

    if isfile(txtFile)
        fid = fopen(txtFile, 'rb');
        raw = fread(fid, '*uint8')'; fclose(fid);
        key = 'eceproject2025';
        dec = bitxor(raw, uint8(key(mod(0:length(raw)-1, length(key))+1)));
        message = char(dec);
        textLen = length(message);
        logMsg("✅ Decrypted Message: " + string(message));
    else
        logMsg("❌ No text message found.");
    end

    if isfile(audioFile)
        [y, fs] = audioread(audioFile);
        audioDur = length(y) / fs;
        logMsg("✅ Audio Duration: " + sprintf('%.2f', audioDur) + " sec");
    else
        logMsg("❌ No audio file found.");
    end

    try
        logMsg("⚙️ Running Hopping...");
        evalc('simulate_temporal_dynamic_hopping');
        plotGraphs();
        plotMetrics(textLen, audioDur);
    catch err
        logMsg("❌ Simulation error: " + err.message);
    end
end


    function plotGraphs()
        try
            d = load('/MATLAB Drive/flask_hopping_project/shared_data/tfh_dch_log.mat');
            tfh = d.tfh_log; dch = d.dch_log;
            eaves = d.eaves_indices; jam = d.jammed;

            % TFH Plot
            cla(axTFH);
            plot(axTFH, tfh, '-ob', 'DisplayName', 'TFH');
            hold(axTFH, 'on');
            if ~isempty(eaves)
                scatter(axTFH, eaves, tfh(eaves), 60, 'm', 'filled', 'DisplayName', 'Eavesdropped');
            end
            title(axTFH, 'Temporal Frequency Hopping');
            xlabel(axTFH, 'Step'); ylabel(axTFH, 'Frequency (Hz)');
            legend(axTFH, 'Location', 'best');
            grid(axTFH, 'on');

            % DCH Plot
            cla(axDCH);
            plot(axDCH, dch, '-xg', 'DisplayName', 'DCH');
            hold(axDCH, 'on');
            scatter(axDCH, find(jam), dch(jam), 60, 'r', 'filled', 'DisplayName', 'Jammed');
            title(axDCH, 'Dynamic Channel Hopping');
            xlabel(axDCH, 'Step'); ylabel(axDCH, 'Frequency (Hz)');
            legend(axDCH, 'Location', 'best');
            grid(axDCH, 'on');

            logMsg("📊 Graphs updated.");
        catch err
            logMsg("❌ Plotting error: " + err.message);
        end
        % Check similarity between TFH and DCH
similarity = sum(abs(tfh - dch) < 5) / length(tfh);  % Tolerance: 5 Hz
if similarity > 0.8
    logMsg("⚠️ TFH and DCH are too similar. Jamming might not be effective.");
end

    end

function plotMetrics(textLen, audioDur)
    try
        delete(tabMetrics.Children); % Clear old

        % Create 4 tabs
        subTabs = uitabgroup(tabMetrics, 'Position', [20 20 1220 310]);
        tabBER = uitab(subTabs, 'Title', '📉 SNR vs BER');
        tabCapacity = uitab(subTabs, 'Title', '📊 Channel Capacity');
        tabThroughput = uitab(subTabs, 'Title', '📈 Throughput');
        tabOutage = uitab(subTabs, 'Title', '⚠️ Outage Probability');

        % 🔧 Adjust SNR range based on input size
        loadFactor = min(2 + textLen / 50 + audioDur / 3, 5);  % Max 5x scale
        snr = 0:2:(20 + round(loadFactor)); % More data = simulate wider SNR range

        ber = qfunc(sqrt(2 * 10.^(snr / 10)));
        capacity = log2(1 + 10.^(snr / 10));
        throughput = 0.8 * capacity;
        outage = qfunc(sqrt(snr));

        % 📉 BER
        ax1 = uiaxes(tabBER, 'Position', [50 20 1100 260]);
        semilogy(ax1, snr, ber, '-ob', 'LineWidth', 2);
        title(ax1, 'SNR vs BER'); xlabel(ax1, 'SNR (dB)'); ylabel(ax1, 'Bit Error Rate'); grid(ax1, 'on');

        % 📊 Capacity
        ax2 = uiaxes(tabCapacity, 'Position', [50 20 1100 260]);
        plot(ax2, snr, capacity, '--k', 'LineWidth', 2);
        title(ax2, 'SNR vs Channel Capacity'); xlabel(ax2, 'SNR (dB)'); ylabel(ax2, 'Capacity'); grid(ax2, 'on');

        % 📈 Throughput
        ax3 = uiaxes(tabThroughput, 'Position', [50 20 1100 260]);
        plot(ax3, snr, throughput, '-xg', 'LineWidth', 2);
        title(ax3, 'SNR vs Throughput'); xlabel(ax3, 'SNR (dB)'); ylabel(ax3, 'Throughput'); grid(ax3, 'on');

        % ⚠️ Outage
        ax4 = uiaxes(tabOutage, 'Position', [50 20 1100 260]);
        plot(ax4, snr, outage, '-.m', 'LineWidth', 2);
        title(ax4, 'SNR vs Outage Probability'); xlabel(ax4, 'SNR (dB)'); ylabel(ax4, 'Outage'); grid(ax4, 'on');

        logMsg("📈 Metrics plotted based on user input.");

    catch err
        logMsg("❌ Metrics plotting error: " + err.message);
    end
end


    function animateGraphs()
        try
            d = load('/MATLAB Drive/flask_hopping_project/shared_data/tfh_dch_log.mat');
            tfh = d.tfh_log; dch = d.dch_log;
            eaves = d.eaves_indices; jam = d.jammed;

            for i = 1:length(tfh)
                plot(axTFH, 1:i, tfh(1:i), '-ob'); hold(axTFH, 'on');
                if ismember(i, eaves), scatter(axTFH, i, tfh(i), 60, 'm', 'filled'); end

                plot(axDCH, 1:i, dch(1:i), '-xg'); hold(axDCH, 'on');
                if jam(i), scatter(axDCH, i, dch(i), 60, 'r', 'filled'); end

                pause(0.4);
            end
            logMsg("🎞️ Animation completed.");
        catch err
            logMsg("❌ Animation failed: " + err.message);
        end
    end

    function cleanup()
        stop(clockTimer); delete(clockTimer);
        stop(syncTimer); delete(syncTimer);
        delete(fig);
    end
end
