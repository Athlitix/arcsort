# ARC-SORT

**Adaptive, Robust, Compensated Multi-Object Tracking with Interacting Multiple Models**

[![arXiv](https://img.shields.io/badge/arXiv-2610.22306-b31b1b.svg)](https://arxiv.org/abs/2610.22306)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

ARC-SORT is a tracking-by-detection multi-object tracker for fast, non-linear motion under a
moving camera, such as athletes in sports broadcasts. Nothing is trained. It works with any detector and
runs at about 50 FPS on a laptop RTX 3060.

The idea: **the tracker measures its own uncertainty, and that measurement decides how it acts.**

- **IMM Kalman filter** (constant velocity / constant acceleration / coordinated turn) gives each
  track a predictive covariance.
- **Uncertainty-adaptive Expansion IoU**: the less reliable a track's motion prediction, the larger
  the region in which a detection may match it.
- **Deferred identity arbitration**: when two tracks cross and the assignment was a close call,
  the pair stays under review; at most one corrective identity swap is applied once post-crossing
  appearance evidence shows the first decision was wrong.
- **Camera-motion compensation**, BYTE two-stage matching, OC-SORT observation-centric recovery,
  and appearance (ReID) costs.
- **Offline tracklet merge** that links players who leave the frame by appearance alone (no
  motion gate, since extrapolating motion over seconds off-screen carries no information).

## Results

Test-set numbers are from the official evaluation servers (CodaBench).

| Benchmark (test) | HOTA | AssA | DetA | MOTA | IDF1 | IDs |
|---|---|---|---|---|---|---|
| SportsMOT | **81.82** | 76.24 | 87.84 | 97.09 | 88.47 | 1414 |
| SportsMOT, Deep-EIoU's detections + embeddings | 80.31 | 74.14 | 87.04 | 96.65 | 86.92 | 1320 |
| DanceTrack | **62.1** | 48.2 | 80.3 | 92.4 | 66.5 | — |

As of August 2026, SportsMOT has the fewest identity switches of all 69 leaderboard entries.
On Deep-EIoU's own inputs, ARC-SORT is +3.1 HOTA over Deep-EIoU (77.2).

Validation numbers, reproducible locally (pooled TrackEval):

| Benchmark (val) | HOTA | AssA | IDF1 |
|---|---|---|---|
| SportsMOT | 84.96 | 82.96 | 92.79 |
| DanceTrack | 60.62 | 47.44 | 64.80 |

## Installation

Python 3.10+ (developed on 3.12).

```bash
git clone https://github.com/Athlitix/arcsort.git && cd arcsort
pip install -e ".[reid,eval]"
```

For the GPU stages (detection, embeddings), install a CUDA build of PyTorch first; see
[pytorch.org](https://pytorch.org/get-started/locally/). Tracking from cached inputs runs on CPU.

External code (clone into `external/`, which is gitignored):

| Repo | Needed for | Command |
|---|---|---|
| [TrackEval](https://github.com/JonathonLuiten/TrackEval) | val evaluation | `git clone https://github.com/JonathonLuiten/TrackEval external/TrackEval` |
| [YOLOX](https://github.com/Megvii-BaseDetection/YOLOX) | regenerating detections | `git clone https://github.com/Megvii-BaseDetection/YOLOX external/YOLOX` |
| [Deep-OC-SORT](https://github.com/GerardMaggiolino/Deep-OC-SORT) | converting DanceTrack ReID weights (bundles FastReID) | `git clone https://github.com/GerardMaggiolino/Deep-OC-SORT external/Deep-OC-SORT` |

## Quick start: track with any detector

ARC-SORT takes boxes and scores from any detector and returns boxes with persistent IDs:

```python
from arcsort import ARCTracker

tracker = ARCTracker.from_preset("sportsmot")       # motion-only, runs on CPU
# tracker = ARCTracker.from_preset("sportsmot", reid_weights="weights/sportsmot/sports_osnet_traced.pt")

for frame in video:                                   # BGR numpy image
    dets = my_detector(frame)                         # (N, 6): x1, y1, x2, y2, score, class_id
    tracks = tracker.update(dets, frame)              # (M, 5): x1, y1, x2, y2, track_id
```

- **Presets**: `sportsmot` (recommended default for sports footage), `dancetrack`, and
  `sportsmot_deepeiou_inputs`. Override any key, e.g.
  `ARCTracker.from_preset("sportsmot", track_buffer=60, eiou={"adaptive_scale": 3.0})`.
- **`frame`** is used for camera-motion compensation and ReID crops. Pass it every frame
  (or `use_cmc=False` for a static camera).
- **ReID** needs the `reid` extra, a CUDA GPU and converted weights (see [Weights](#weights)).
  Without it the tracker runs motion-only.
- **Detection scores matter**: thresholds (`track_high_thresh` 0.6, `new_track_thresh` 0.7) are
  calibrated for YOLOX-X. If your detector's scores run lower, lower them.
- **supervision** users: `arcsort.interop.from_supervision(detections)` and
  `to_supervision(tracks)` convert to and from `sv.Detections` (`pip install arcsort[viz]`).
- Start a new video with `tracker.reset()`.

## Reproducing the paper

One command per row:

```bash
scripts/reproduce.sh sportsmot val            # prints HOTA 84.957
scripts/reproduce.sh dancetrack val           # prints HOTA 60.617
scripts/reproduce.sh sportsmot test           # writes outputs/arcsort_sportsmot_test.zip
scripts/reproduce.sh dancetrack test          # writes outputs/arcsort_dancetrack_test.zip
scripts/reproduce.sh sportsmot_deepeiou test  # Deep-EIoU's inputs
```

Upload test zips to the [SportsMOT](https://www.codabench.org/competitions/13077/) or
[DanceTrack](https://www.codabench.org/competitions/14885/) CodaBench server.

The script runs five stages and skips any stage whose output already exists:

1. **detections**: YOLOX-X, one file per sequence (GPU)
2. **camera motion**: one affine transform per frame (CPU)
3. **embeddings**: ReID features for every detection (GPU)
4. **tracking**: online tracker → interpolation (gaps ≤ 10 frames) → offline tracklet merge (CPU)
5. **evaluation** (val) or **packaging** (test)

### Fast path: released caches (exact reproduction)

The [GitHub release](https://github.com/Athlitix/arcsort/releases) contains our cached detections and
camera-motion transforms. With them, stages 1–2 are skipped:

```
cache/
  detections/{sportsmot,dancetrack}_{val,test}/<seq>.txt
  cmc/{sportsmot,dancetrack}_{val,test}/<seq>.npy
  embeddings/{sportsmot,dancetrack}_{val,test}/<seq>.npz   # computed by stage 3
```

The release also contains our submitted test-result zips. `scripts/regression_gate.sh` reruns the
tracking chain and checks that every output file is byte-identical to them.

Detector and ReID outputs can differ in the last bits across GPU models and library versions.
When you regenerate the caches, expect numbers within noise of the paper, not byte-identical files.
Our results were produced on an RTX 3060 Laptop GPU with torch 2.5.1+cu121, numpy 2.4.3,
opencv-python 4.13.0, scipy 1.17.1 and lap 0.5.13.

### Datasets

Download [SportsMOT](https://github.com/MCG-NJU/SportsMOT) and
[DanceTrack](https://github.com/DanceTrack/DanceTrack) and arrange them in MOTChallenge layout:

```
data/
  SportsMOT/{val,test}/<seq>/{img1/,gt/,seqinfo.ini}
  DanceTrack/{val,test}/<seq>/{img1/,gt/,seqinfo.ini}
```

Frames are needed for stages 1–3 only. Val evaluation needs `gt/`.

### Weights

Weights are not redistributed here. Download them from the original authors:

| File in `weights/` | Used for | Source |
|---|---|---|
| `sportsmot/yolox_x_sports_train.pth.tar` | SportsMOT **val** detections (train-split checkpoint, so no val frame was seen) | [MixSort model zoo](https://github.com/MCG-NJU/MixSort) |
| `sportsmot/yolox_x_sports_mix.pth.tar` | SportsMOT **test** detections (train+val checkpoint) | [MixSort model zoo](https://github.com/MCG-NJU/MixSort) |
| `ocsort_dance_model.pth.tar` | DanceTrack detections | [OC-SORT model zoo](https://github.com/noahcao/OC_SORT) |
| `sportsmot/sports_osnet_traced.pt` | SportsMOT ReID | converted from Deep-EIoU's `sports_model.pth.tar-60` ([Deep-EIoU](https://github.com/hsiangwei0903/Deep-EIoU)), see below |
| `dance_sbs_S50_traced.pt` | DanceTrack ReID | converted from FastReID `dance_sbs_S50.pth` ([Deep-OC-SORT](https://github.com/GerardMaggiolino/Deep-OC-SORT)), see below |

ReID conversion to TorchScript (one-time, needs a CUDA GPU):

```bash
# SportsMOT: sports-domain OSNet from Deep-EIoU
python tools/extract_state_dict.py --input sports_model.pth.tar-60 \
    --output weights/sportsmot/sports_osnet_clean.pth
python tools/convert_osnet_weights.py --input weights/sportsmot/sports_osnet_clean.pth \
    --output weights/sportsmot/sports_osnet_traced.pt

# DanceTrack: FastReID SBS-S50 (needs external/Deep-OC-SORT)
python tools/convert_reid_weights.py --input dance_sbs_S50.pth \
    --output weights/dance_sbs_S50_traced.pt --config dancetrack
```

`extract_state_dict.py` loads the training checkpoint with `weights_only=False`, so only run it
on files from the official release.

For the Deep-EIoU-inputs row, download Deep-EIoU's released SportsMOT test detections and
embeddings into `external/Deep-EIoU/{detection,embedding}/` (or set `DEEP_EIOU_ASSETS`).

## Repository layout

```
arcsort/          tracker package (IMM-KF, EIoU, CMC, ReID, arbitration, OC-SORT components)
arcsort/configs/  presets = the exact configurations behind each paper row
configs/detector/ YOLOX experiment files
tools/            caching, tracking, post-processing, evaluation, FPS benchmark, video demo
scripts/          reproduce.sh, regression_gate.sh
tests/            unit tests (pytest)
third_party/      vendored OSNet architecture (MIT)
```

## Citation

```bibtex
@article{adari2026arcsort,
  title   = {{ARC-SORT}: Adaptive, Robust, Compensated Multi-Object Tracking with Interacting Multiple Models},
  author  = {Adari, Girish Kumar},
  journal = {arXiv preprint arXiv:2610.22306},
  year    = {2026}
}
```

## License

Apache License 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE). ARC-SORT builds on OC-SORT,
ByteTrack, BoT-SORT and Deep OC-SORT; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Pretrained weights and datasets are subject to their own licenses and terms, which may restrict
commercial use independently of this code's license.
