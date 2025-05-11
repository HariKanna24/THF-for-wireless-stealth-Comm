function download_from_github()
    % Path setup
    shared_folder = '/MATLAB Drive/flask_hopping_project/shared_data';

    if ~isfolder(shared_folder)
        mkdir(shared_folder);
    end

    % File URLs from GitHub (replace with your actual repo and branch)
    base_url = 'https://raw.githubusercontent.com/Nkdcg/flask_hopping/main/shared_data/';
    files = {
        'text_message.txt'
        'uploaded_audio.wav'
        'simulation_flags.json'
        'hopping_config.json'
    };

    for i = 1:length(files)
        try
            file_url = [base_url files{i}];
            save_path = fullfile(shared_folder, files{i});
            websave(save_path, file_url);
        catch
            fprintf("⚠️ Failed to download: %s\n", files{i});
        end
    end

    fprintf("✅ Downloaded files from GitHub.\n");
end
