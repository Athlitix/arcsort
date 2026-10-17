# Third-Party Notices

ARC-SORT is licensed under the Apache License 2.0 (see `LICENSE`).
It builds on the following third-party work. Upstream license texts
were verified against the upstream repositories on 2026-07-24.

## Code vendored in this repository

| Component | Location | License | Notes |
|---|---|---|---|
| OSNet backbone (deep-person-reid, Kaiyang Zhou) | `external/osnet/` | MIT — Copyright (c) 2018 Kaiyang Zhou (`external/osnet/LICENSE`) | vendored for TorchScript export in `tools/convert_osnet_weights.py` |
| TrackEval (Jonathon Luiten) | `external/TrackEval/` | MIT — Copyright (c) 2020 Jonathon Luiten | evaluation only |
| YOLOX (Megvii) | `external/YOLOX/` | Apache-2.0 | detection inference for cached detections |

## Code lineage (algorithms adapted/reimplemented, not verbatim copies)

| Upstream | License | What ARC-SORT uses |
|---|---|---|
| OC-SORT (github.com/noahcao/OC_SORT) | MIT — Copyright (c) 2021 Yifu Zhang (their LICENSE file) | ORU/OCM/OCR mechanisms (`arcsort/ocsort_components.py`, adapted) |
| ByteTrack (github.com/ifzhang/ByteTrack) | MIT — Copyright (c) 2021 Yifu Zhang | two-stage confidence split (reimplemented) |
| BoT-SORT (github.com/NirAharon/BoT-SORT) | MIT — Copyright (c) 2022 Nir Aharon | sparse-flow CMC pattern, size-dependent noise (reimplemented) |
| Deep OC-SORT (github.com/GerardMaggiolino/Deep-OC-SORT) | no LICENSE file found upstream at time of writing | adaptive-weighting formula (reimplemented from the paper; inert in shipped config) |
| FastReID (JDAI-CV) | Apache-2.0 | SBS-S50 ReID export path (DanceTrack only) |

## Model weights (NOT distributed with this repository)

Weights are downloaded from their original sources; this repository
ships only conversion scripts. Do not re-host these files.

| Weights | Source | Upstream license status |
|---|---|---|
| YOLOX-X SportsMOT (`yolox_x_sports_mix/train.pth.tar`) | MixSort model zoo (github.com/MCG-NJU/MixSort, Google Drive) | repo MIT — Copyright (c) 2021 Yifu Zhang; weights trained on SportsMOT (see dataset terms below) |
| Sports OSNet (`sports_model.pth.tar-60`) + detector (`best_ckpt.pth.tar`) + public test detections/embeddings | Deep-EIoU release (github.com/hsiangwei0903/Deep-EIoU, Google Drive) | **no LICENSE file in upstream repo** — used with citation for research comparison; not redistributed |
| FastReID SBS-S50 (dance/mot17/mot20) | Deep-OC-SORT / FastReID model zoos | see upstream |
| YOLOX-X DanceTrack | OC-SORT model zoo | MIT (repo) |

## Datasets

SportsMOT and DanceTrack are used under their respective research
terms. Note for any commercial deployment: models trained on these
datasets (including the third-party weights above) may be restricted
by dataset terms independently of any code license.
