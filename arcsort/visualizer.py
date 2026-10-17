"""Visualization engine using supervision for ARC-SORT pipeline.

Draws bounding boxes, track IDs, and movement trails on video frames.
Supports side-by-side view (original | annotated) and FPS overlay.

Usage:
    from arcsort.visualizer import Visualizer

    viz = Visualizer(trace_length=30)
    annotated = viz.annotate(frame, tracks, fps=25.3)
    combined = Visualizer.side_by_side(frame, annotated)
"""

from __future__ import annotations

import cv2
import numpy as np
import supervision as sv


class Visualizer:
    """Annotate frames with tracking results using supervision."""

    def __init__(
        self,
        trace_length: int = 30,
        show_labels: bool = True,
    ) -> None:
        """Initialize annotators.

        Args:
            trace_length: Track trail length in frames. 0 disables trails.
            show_labels: Show track ID labels on boxes.
        """
        self.show_labels = show_labels
        self.box_annotator = sv.BoxAnnotator(
            thickness=2,
            color_lookup=sv.ColorLookup.TRACK,
        )
        self.label_annotator = sv.LabelAnnotator(
            text_scale=0.5,
            text_thickness=1,
            text_position=sv.Position.TOP_LEFT,
            color_lookup=sv.ColorLookup.TRACK,
        )
        self.trace_annotator = None
        if trace_length > 0:
            self.trace_annotator = sv.TraceAnnotator(
                trace_length=trace_length,
                thickness=2,
                position=sv.Position.BOTTOM_CENTER,
                color_lookup=sv.ColorLookup.TRACK,
            )

    def annotate(
        self,
        frame: np.ndarray,
        tracks: np.ndarray,
        fps: float | None = None,
    ) -> np.ndarray:
        """Draw tracks on frame.

        Args:
            frame: BGR image (H, W, 3).
            tracks: (M, 5) [x1, y1, x2, y2, track_id] from tracker.update().
            fps: Optional FPS to overlay on frame.

        Returns:
            Annotated copy of the frame.
        """
        annotated = frame.copy()

        if tracks.shape[0] > 0:
            tracker_ids = tracks[:, 4].astype(int)
            detections = sv.Detections(
                xyxy=tracks[:, :4],
                tracker_id=tracker_ids,
            )

            if self.trace_annotator is not None:
                annotated = self.trace_annotator.annotate(annotated, detections)
            annotated = self.box_annotator.annotate(annotated, detections)

            if self.show_labels:
                labels = [f"ID:{tid}" for tid in tracker_ids]
                annotated = self.label_annotator.annotate(
                    annotated, detections, labels=labels,
                )

        if fps is not None:
            cv2.putText(
                annotated,
                f"FPS: {fps:.1f}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.0,
                (0, 255, 0),
                2,
                cv2.LINE_AA,
            )

        return annotated

    @staticmethod
    def side_by_side(
        original: np.ndarray, annotated: np.ndarray,
    ) -> np.ndarray:
        """Combine original and annotated frames horizontally."""
        return np.hstack([original, annotated])
