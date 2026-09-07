# sEMG Signal Processing and Visualization Dashboard

This project builds a complete surface EMG (sEMG) processing in
MATLAB, from raw voltage readings to a smoothed muscle activation
envelope for both isometric and isotonic contraction conditions, and
pairs it with an interactive Python (Streamlit) dashboard for exploring
both.



Note: DEMO VIDEO AVAILABLE 



## Why I did this project

I started from a reference document along with the dataset  that laid out an sEMG processing
workflow tested on a 10-subject dataset. I wanted to implement that same kind of
processing pipeline myself, on real recordings, and understand. My first working version of the
envelope-smoothing step had a bug where the smoothing window was
calculated in units of the original 2000 Hz sample rate, but applied to
an envelope I had already downsampled to about 300 points, a window
bigger than the entire array. It didn't throw an  error but just
implemented a much cruder smoothing method. For the isometric recording
I ran diagnostics on my own signal and found the a pattern
the first 20s was the *quietest* part, not the noisiest of the signal.

After getting the isometric pipeline working, I processed the isotonic
recording from the same subject to see whether my processing decisions
would actually generalize but they didn't, and that turned out to be one
of the more useful findings in the whole project (see **Results** and
**Discussion** below).

## What this project does

1. Loads and cleans raw sEMG recordings for both isometric and isotonic
contractions (detrending, missing-value handling).
2. Removes 60 Hz power-line interference with a notch filter.
3. Bandpass filters the signal to the standard 20-450 Hz sEMG range.
4. Runs independent stability diagnostics per condition like RMS ratio,
raw-signal plot, low-frequency drift plot to decide, per recording,
whether to trim the first 20 seconds
5. Extracts a smoothed linear envelope representing muscle activation
intensity over time (rectify, low-pass and Savitzky-Golay smoothing).
6. Exports the processed signal and envelope for both conditions to CSV.
7. Displays both conditions in an interactive Streamlit dashboard, with
a condition selector, channel selector, time-range slider, and basic
signal metrics like RMS, median frequency, spectral entropy, skewness,
kurtosis.

## Dataset

I used two recordings from the same subject (**`user1`**), from a public
sEMG dataset on Zenodo, recorded from two electrode sites on the biceps
brachii:

* **BCC** : Biceps Caput Corne (short head)
* **BCL** : Biceps Caput Longum (long head)
* Sampling rate: 2000 Hz
* Duration: 60 seconds per recording
* Conditions: `user1\\\_isometrica.csv` (sustained contraction),
`user1\\\_isotonica.csv` (dynamic, repeated-movement contraction)

**Dataset citation:**

* sEMG dataset accessed via Zenodo (embedded sEMG acquisition platform
evaluation dataset).

## Methodology

### 1\. Preprocessing

Firstly, unprocessed values are converted from text to numeric, missing
samples are handled, and linear baseline drift is removed with
`detrend('linear')`. Baseline offset from skin-electrode contact
impedance is a well-documented non-physiological artifact and standard
to remove before filtering \[1].

### 2\. Notch filter (60 Hz, Q=30)

A narrow band-reject biquad filter used to remove 60 Hz mains interference,
applied via `filtfilt` for zero-phase filtering. A 60 Hz notch alongside
a bandpass stage is standard sEMG signal conditioning practice \[2].

### 3\. Bandpass filter (20-450 Hz, 4th-order Butterworth)

I used bandwidths in sEMG literature with several
published studies using this  filter order and cutoff pair \[3]\[4],
reflecting standard practice from the SENIAM surface EMG standardization
project \[5].

### 4\. Per-condition windowing decision

Rather than applying one windowing rule to both conditions, I ran the
same three diagnostics such as RMS ratio, raw-signal plot with a 20s marker,
low-frequency drift plot independently on each recording. The two
conditions gave opposite answers — see **Results**.

### 5\. Envelope extraction

The bandpassed signal is full-wave rectified and low-pass filtered to
obtain a smooth linear envelope, a standard rectify then smooth approach
for sEMG envelope extraction \[1]\[6]. I tested several cutoffs (10, 6, 4,
3 Hz) before settling on **5 Hz**.

### 6\. Savitzky-Golay smoothing (250 ms window, 3rd-order polynomial)

A final polynomial smoothing pass preserves the shape of activation
peaks better than a simple moving average would \[7].

**Method citations:**

1. De Luca, C. J. (1997). The use of surface electromyography in
biomechanics. *Journal of Applied Biomechanics*, 13(2), 135-163.
https://doi.org/10.1123/jab.13.2.135
2. Multiple clinical sEMG protocols specify a 20-450 Hz Butterworth
bandpass combined with a 60 Hz notch as standard conditioning
(e.g., studies following SENIAM guidelines).
3. Islam, M. A., et al. Does heel height cause imbalance during
sit-to-stand task: Surface EMG perspective. Filtered using a
4th-order Butterworth bandpass, 20-450 Hz.
https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5581500/
4. Noraxon (2024). *EMG Signal Processing: Key Techniques and Practical
Recommendations.* https://www.noraxon.com/?p=26750
5. Hermens, H. J., Freriks, B., Disselhorst-Klug, C., \& Rau, G. (2000).
Development of recommendations for SEMG sensors and sensor placement
procedures. *Journal of Electromyography and Kinesiology*, 10(5),
361-374. https://doi.org/10.1016/S1050-6411(00)00027-4
6. Rectify-then-low-pass is a widely used method for constructing a
linear EMG envelope; low-pass cutoffs in the 3-10 Hz range are common.
7. Savitzky, A., \& Golay, M. J. E. (1964). Smoothing and differentiation
of data by simplified least squares procedures. *Analytical
Chemistry*, 36(8), 1627-1639. https://doi.org/10.1021/ac60214a047

## Results

### Windowing diagnostics: Isometric and Isotonic

|Segment|BCL RMS ratio (0-60s)|BCC RMS ratio (0-60s)|
|-|-|-|
|Isometric|0.50x|0.48x|
|Isotonic|1.71x|1.49x|

The pattern flipped between conditions. For isometric, the first 20s was
the *quietest* part of the recording so the
**full 60 seconds** was used. For isotonic, the first 20s had noticeably
*more* energy than the rest, and the drift plot showed a clear, isolated
excursion concentrated in the first \~12 seconds, consistent with the subject settling into the repetitive
movement. Based on that evidence, the **first 20 seconds were trimmed**
for isotonic, using the **20-60s** window for all further processing.

### Envelope smoothing: effect of low-pass cutoff

|Condition|Window|Cutoff|Correlation (raw envelope vs. smoothed)|
|-|-|-|-|
|Isometric|Full 60s|10 Hz|0.671|
|Isometric|Full 60s|6 Hz|0.925|
|Isometric|Full 60s|4 Hz|0.997|
|Isometric|Full 60s|3 Hz|0.999|
|Isotonic|Full 60s|5 Hz|0.9965|
|Isotonic|Trimmed 20-60s|10 Hz|0.8928|
|Isotonic|Trimmed 20-60s|5 Hz|0.9963|

**5 Hz** was selected as the final cutoff for both conditions. The
isotonic results in particular show this holds up consistently whether the full recording or the trimmed window is used.

## Discussion

The windowing result was the most useful finding here. I expected the
reference document in the dataset folder  reasoning  to
either always apply or never apply, and instead it applied to one
condition and not the other, for the same subject and equipment. That
suggests instability in this kind of recording may be more tied to *what
the muscle is actually doing*
than to the acquisition hardware itself. A sustained isometric
contraction has less reason to show a settling-in transient than a
dynamic, repeated-movement isotonic one does.

The envelope cutoff result was more expected but still worth confirming
5 Hz held up as the right choice across two different conditions and two
different windowing decisions.

## Limitations

* Single-subject data (`user1` only, both conditions)
* The isotonic trimming decision, while evidence-based, was made by quantitative inspection rather than a formal changepoint detection method.
* Envelope low-pass cutoff  was chosen through a small manual
parameter sweep, not a formal optimization procedure.

## Future Work

* Extend the pipeline to multiple subjects in the dataset.
* Add inter-channel (BCC vs. BCL) correlation analysis.
* Make the envelope cutoff and smoothing window adjustable directly from
the dashboard rather than fixed in the MATLAB script.
* Apply a formal changepoint detection method to the windowing decision
instead of the current RMS-ratio approach.

## Repository structure

```
├── README.md
├── LICENSE
├── requirements.txt
├── dashboard3_python1.py          # Streamlit dashboard (both conditions)
├── emg_signal_processing3_final.m # MATLAB processing pipeline
├── Data_set_EMG_Repository/       # Dataset (Raw, filtered, etc.)
├── Demo/
│   └── demo_dashboard.mp4         # Walkthrough video
├── Figures/                       # Static plots (filter stages, diagnostics)
└── python_dashboard3_data/        # Processed data files (isometric, isotonic)              
```

## How to run it

1. Download `user1\\\_isometrica.csv` and `user1\\\_isotonica.csv` from the
Zenodo dataset.
2. Open `emg\\\_signal\\\_processing3\\\_final.mlx` in MATLAB, import each CSV as
a table, and run the script (setting `ANALYSIS\\\_MODE` appropriately
per condition — `'full'` for isometric, `'trimmed'` for isotonic) —
this produces the eight CSVs in `python\\\_dashboard3\\\_data/`.
3. Run `pip install -r requirements.txt`, then
`streamlit run dashboard3\\\_python.py` to launch the dashboard locally.
Use the sidebar's Condition selector to switch between Isometric and
Isotonic.

## Demo

A walkthrough video of the dashboard, covering both conditions, is
included in this repository (`demo/dashboard\\\_demo.mp4`, playable
directly on GitHub).

