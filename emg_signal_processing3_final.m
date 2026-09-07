%% EMG Signal processing on Matlab
% Author: Eza Yasir
% Date: July 2026
%
% Description: Real sEMG data taken from Zenodo. Raw, unprocessed signals
% from sensors on Biceps Caput Corne (BCC, short head) and Biceps Caput
% Longum (BCL, long head).
%
% Processing: detrending, notch filter,  bandpass filter,  full-rate
% rectify and low-pass envelope, Savitzky-Golay smoothing and finally 
% Python dashboard export.
%
% Window: FULL 60s used for isometric and trimmed for isotonic condition. Diagnostics (RMS/raw-plot/drift-plot) used.


%
% Section 1: Loading and cleaning of user1_isometrica data

% A part: imported as table user1_isometrica from the CSV file.

BCL_signal = user1_isometrica.BCL;
BCC_signal = user1_isometrica.BCC;

% Conversion to numeric data since the csv file has text values
BCL_signal = str2double(string(BCL_signal));
BCC_signal = str2double(string(BCC_signal));

% Replacing any NaN (Not-a-Number) values with 0
BCL_signal(isnan(BCL_signal)) = 0;
BCC_signal(isnan(BCC_signal)) = 0;

% Removing DC offset using linear detrending method
BCL_signal = detrend(BCL_signal, 'linear');
BCC_signal = detrend(BCC_signal, 'linear');

% Sampling frequency
Fs = 2000;

% Time vector
t = (0:length(BCL_signal)-1) / Fs;


%% Section B part: Stability diagnostics run on FULL signal and windowing choice

%%  Diagnostic 1: RMS comparison, first 20s and the rest 
seg1 = 1:(20*Fs);                    % 0-20 s
seg2 = (20*Fs+1):length(BCL_signal); % 20-60 s

bcl_rms_seg1 = sqrt(mean(BCL_signal(seg1).^2));
bcl_rms_seg2 = sqrt(mean(BCL_signal(seg2).^2));
bcc_rms_seg1 = sqrt(mean(BCC_signal(seg1).^2));
bcc_rms_seg2 = sqrt(mean(BCC_signal(seg2).^2));

fprintf(' Stability diagnostics for full 60s signal \n');
fprintf('BCL RMS [0-20s]: %.4e   BCL RMS [20-60s]: %.4e   Ratio: %.2fx\n', ...
    bcl_rms_seg1, bcl_rms_seg2, bcl_rms_seg1/bcl_rms_seg2);
fprintf('BCC RMS [0-20s]: %.4e    BCC RMS [20-60s]: %.4e    Ratio: %.2fx\n', ...
    bcc_rms_seg1, bcc_rms_seg2, bcc_rms_seg1/bcc_rms_seg2);



%% Diagnostic 2: Raw signal plot with a marker at the 20s cutoff 
figure('Name', 'Raw Signal - Stability Check', 'NumberTitle', 'off', ...
    'Position', [50, 50, 1200, 700]);

subplot(2,1,1);
plot(t, BCL_signal, 'y'); hold on;
xline(20, 'r--', 'LineWidth', 1.5, 'Label', '20s cutoff');
title('BCL Raw Signal - Stability Check', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); grid on; hold off;

subplot(2,1,2);
plot(t, BCC_signal, 'g'); hold on;
xline(20, 'r--', 'LineWidth', 1.5, 'Label', '20s cutoff');
title('BCC Raw Signal - Stability Check', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); grid on; hold off;



%%  Diagnostic 3: Low-frequency drift (less than 1 Hz) 
[b_drift, a_drift] = butter(2, 1/(Fs/2), 'low');
bcl_drift = filtfilt(b_drift, a_drift, BCL_signal);
bcc_drift = filtfilt(b_drift, a_drift, BCC_signal);

figure('Name', 'Low-Frequency Drift Check', 'NumberTitle', 'off', ...
    'Position', [50, 50, 1200, 700]);

subplot(2,1,1);
plot(t, bcl_drift, 'b'); hold on;
xline(20, 'r--', 'LineWidth', 1.5, 'Label', '20s cutoff');
title('BCL Low-Frequency Drift ', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); grid on; hold off;

subplot(2,1,2);
plot(t, bcc_drift, 'r'); hold on;
xline(20, 'r--', 'LineWidth', 1.5, 'Label', '20s cutoff');
title('BCC Low-Frequency Drift ', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); grid on; hold off;





%% Applying windowing decision 
% Diagnostics showed no instability in the first 20s for the data from the recording,
% so i used the full 60s of the signal time frame

ANALYSIS_MODE = 'full';   % 'full' = all 60 s  while 'trimmed' = 20-60 s  

switch ANALYSIS_MODE
    case 'trimmed'
        start_sample = 20 * Fs + 1;
        BCL_signal   = BCL_signal(start_sample:end);
        BCC_signal   = BCC_signal(start_sample:end);
        t            = t(start_sample:end);
    case 'full'
        
    otherwise
        error('ANALYSIS_MODE must be ''full'' or ''trimmed''.');
end

fprintf('Analysis mode selected: %s | Samples used: %d | Time range: %.2f-%.2f s\n\n', ...
    ANALYSIS_MODE, length(BCL_signal), t(1), t(end));






%% Plotting of Raw Signal 

figure('Name', 'Raw BCL EMG Signals', 'NumberTitle', 'off');
subplot(2,1,1);
plot(t, BCL_signal, 'y');
title('BCL Unprocessed EMG Signal');
xlabel('Time (s)'); ylabel('Amplitude');
grid on;

subplot(2,1,2);
plot(t, BCC_signal, 'g');
title('BCC, Raw EMG Signal');
xlabel('Time (s)'); ylabel('Amplitude');
grid on;

fprintf('Section 1 completed: data loading, detrending, sample rate, time vector\n');





%% Section 2: Notch filter to remove 60 Hz power line interference

notch_f = 60;               % frequency to remove
notch_Qualityfactor = 30;   % sharpness of the notch

wo = notch_f / (Fs/2);      % normalized frequency
bw = wo / notch_Qualityfactor;

% Standard biquad notch design (RBJ Audio-EQ-Cookbook formula)
alpha = sin(wo) / (2 * notch_Qualityfactor);

b0 = 1;
b1 = -2 * cos(wo);
b2 = 1;
a0 = 1 + alpha;
a1 = -2 * cos(wo);
a2 = 1 - alpha;

b = [b0, b1, b2] / a0;
a = [1, a1/a0, a2/a0];

% Zero-phase filtering to avoid delay
bcl_notch = filtfilt(b, a, BCL_signal);
bcc_notch = filtfilt(b, a, BCC_signal);

figure('Name', 'Notch Filter Effect', 'NumberTitle', 'off', ...
    'Position', [50, 50, 1400, 900]);

subplot(2,2,1);
plot(t, BCL_signal, 'y', 'LineWidth', 1.0);
title('BCL - Before Notch', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); grid on;

subplot(2,2,2);
plot(t, bcl_notch, 'b', 'LineWidth', 1.0);
title('BCL with Notch', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); grid on;

subplot(2,2,3);
plot(t, BCC_signal, 'g', 'LineWidth', 1.0);
title('BCC - Before Notch', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); grid on;

subplot(2,2,4);
plot(t, bcc_notch, 'r', 'LineWidth', 1.5);
title('BCC - After Notch', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); grid on;

sgtitle('Notch Filter Effect (60 Hz Power Line Removal)', 'FontSize', 16, 'FontWeight', 'bold');

fprintf('Section 2: Notch filter applied, 60 Hz interference removed\n');






%% Section 3: Band Pass Filtering 

order = 4;
low_cutoff = 20;
high_cutoff = 450;

[b_band, a_band] = butter(order, [low_cutoff high_cutoff]/(Fs/2), 'bandpass');

bcl_filtered = filtfilt(b_band, a_band, bcl_notch);
bcc_filtered = filtfilt(b_band, a_band, bcc_notch);

figure('Name', 'Bandpass Filter Effect', 'NumberTitle', 'off', ...
    'Position', [50, 50, 1400, 900]);

subplot(2,2,1);
plot(t, bcl_notch, 'b', 'DisplayName', 'Notch BCL', 'LineWidth', 1.0);
title('BCL - Notch Filter', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); legend('show'); grid on;

subplot(2,2,2);
plot(t, bcl_filtered, 'c', 'DisplayName', 'BCL Bandpass', 'LineWidth', 1.5);
title('BCL - Bandpass Filter', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); legend('show'); grid on;

subplot(2,2,3);
plot(t, bcc_notch, 'r', 'DisplayName', 'BCC Notch', 'LineWidth', 1.0);
title('BCC - Notch Filter', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); legend('show'); grid on;

subplot(2,2,4);
plot(t, bcc_filtered, 'm', 'DisplayName', 'BCC Bandpass', 'LineWidth', 1.5);
title('BCC - Bandpass Filter', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude (mV)'); legend('show'); grid on;

sgtitle('Bandpass Filter Effect (20-450 Hz, 4th Order Butterworth)', 'FontSize', 16, 'FontWeight', 'bold');

fprintf('Section 3: Bandpass filter applied', order);







%% Section 4: Envelope extraction (full-wave rectify and low-pass, full sample rate)

bcl_rect = abs(bcl_filtered);
bcc_rect = abs(bcc_filtered);

envelope_cutoff_hz = 5;   %  linear-envelope cutoff, used 5Hz because among the tested cutoff 5Hz raw envelope variance was stable after the smoothing step
[b_env, a_env] = butter(4, envelope_cutoff_hz / (Fs/2), 'low');

bcl_envelope = filtfilt(b_env, a_env, bcl_rect);
bcc_envelope = filtfilt(b_env, a_env, bcc_rect);

% Envelope is full-rate
time_axis = t;

figure('Name', 'Linear Envelope (Rectify + Low-pass)', 'NumberTitle', 'off', ...
    'Position', [100, 100, 1000, 600]);

subplot(2,1,1);
plot(time_axis, bcl_envelope, 'c', 'DisplayName', 'BCL Envelope', 'LineWidth', 1.2);
title('BCL - Linear Envelope (pre-smoothing)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); legend('show'); grid on;

subplot(2,1,2);
plot(time_axis, bcc_envelope, 'm', 'DisplayName', 'BCC Envelope', 'LineWidth', 1.2);
title('BCC - Linear Envelope (pre-smoothing)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); legend('show'); grid on;

sgtitle('Linear Envelope (Full-wave Rectification and Low-pass Filter)', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('Section 4: Envelope extracted via rectify + %d Hz low-pass, kept at %d Hz\n', ...
    envelope_cutoff_hz, Fs);






%% Section 5: Savitzky-Golay smoothing 

SAVGOL_WINDOW_S  = 0.25;   % 250 ms
SAVGOL_POLYORDER = 3;      % 3rd order

window_len = round(SAVGOL_WINDOW_S * Fs);
if mod(window_len, 2) == 0
    window_len = window_len + 1;
end

if window_len >= length(bcl_envelope)
    error(['Savitzky-Golay window (%d samples) is longer than the envelope ' ...
           '(%d samples). Check Fs / envelope length.'], window_len, length(bcl_envelope));
end

bcl_smooth = sgolayfilt(bcl_envelope, SAVGOL_POLYORDER, window_len);
bcc_smooth = sgolayfilt(bcc_envelope, SAVGOL_POLYORDER, window_len);

fprintf('Section 5: Savitzky-Golay smoothing applied (window=%d samples = %.0f ms, order=%d)\n', ...
    window_len, window_len/Fs*1000, SAVGOL_POLYORDER);

figure('Name', 'Smoothing Effect', 'NumberTitle', 'off', ...
    'Position', [100, 100, 1400, 900]);

subplot(2,1,1);
plot(time_axis, bcl_envelope, 'Color', [0 0 0], 'DisplayName', 'BCL - Envelope (raw)', 'LineWidth', 0.8);
hold on;
plot(time_axis, bcl_smooth, 'c', 'DisplayName', 'BCL - Smoothed', 'LineWidth', 1.8);
hold off;
title('BCL - Smoothed Envelope', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); legend('show'); grid on;

subplot(2,1,2);
plot(time_axis, bcc_envelope, 'Color', [0 0 0], 'DisplayName', 'BCC - Envelope (raw)', 'LineWidth', 0.8);
hold on;
plot(time_axis, bcc_smooth, 'm', 'DisplayName', 'BCC - Smoothed', 'LineWidth', 1.8);
hold off;
title('BCC - Smoothed Envelope', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Amplitude'); legend('show'); grid on;

sgtitle('Smoothing Effect (Savitzky-Golay: 250 ms, Order 3, Full Sample Rate)', 'FontSize', 16, 'FontWeight', 'bold');





fprintf('BCL - Envelope RMS Mean: %.6e\n', mean(bcl_envelope));
fprintf('BCL - Smoothed RMS Mean: %.6e\n', mean(bcl_smooth));
correlation = corrcoef(bcl_envelope, bcl_smooth);
fprintf('BCL - Correlation Envelope vs Smoothed: %.4f\n', correlation(1,2));








%% Section 7: Exporting data for python dashboard

if ~exist('python_dashboard3_data', 'dir')
    mkdir('python_dashboard3_data');
end

% Filtered signals
filtered_data = [t(:), bcl_filtered(:), bcc_filtered(:)];
filtered_data_table = array2table(filtered_data, ...
    'VariableNames', {'Time_s', 'BCL_Filtered', 'BCC_Filtered'});
writetable(filtered_data_table, 'filtered_emg3_signal.csv');
fprintf('Saved: filtered_emg3_signal.csv\n');

% Raw (pre-smoothing) envelope
envelope_raw_data = [time_axis(:), bcl_envelope(:), bcc_envelope(:)];
envelope_raw_table = array2table(envelope_raw_data, ...
    'VariableNames', {'Time_s', 'BCL_Envelope_Raw', 'BCC_Envelope_Raw'});
writetable(envelope_raw_table, 'emg3_envelope_raw.csv');
fprintf('Saved: emg3_envelope_raw.csv\n');

% Smoothed envelope (main dashboard data)
envelope_smooth_data = [time_axis(:), bcl_smooth(:), bcc_smooth(:)];
envelope_smooth_table = array2table(envelope_smooth_data, ...
    'VariableNames', {'Time_s', 'BCL_Envelope_Smoothed', 'BCC_Envelope_Smoothed'});
writetable(envelope_smooth_table, 'emg3_envelope_smoothed.csv');
fprintf('Saved: emg3_envelope_smoothed.csv\n');

% Sample rate info
info_table = table({'Fs'}, {Fs}, 'VariableNames', {'Parameter', 'Value'});
writetable(info_table, 'sampling_info3.csv');
fprintf('Saved: sampling_info3.csv\n');

fprintf('\nAll data saved!\n');