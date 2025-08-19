from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List

@dataclass(order=True)
class Booking:
    """Represents a reservation for a box."""
    start: datetime
    end: datetime
    user: str = field(compare=False)

    def overlaps(self, other: "Booking") -> bool:
        """Return True if this booking overlaps with another."""
        return not (self.end <= other.start or self.start >= other.end)

class BookingSystem:
    """Manage reservations for recording boxes."""

    def __init__(self, boxes: List[str]):
        self.boxes = boxes
        # Mapping of box name -> list of bookings
        self._schedule: Dict[str, List[Booking]] = {box: [] for box in boxes}

    def reserve(self, user: str, box: str, start: datetime, end: datetime) -> Booking:
        """Reserve a box for the given user.

        Raises:
            ValueError: if the box is unknown, times are invalid or slot taken.
        """
        if box not in self.boxes:
            raise ValueError(f"Unknown box: {box}")
        if start >= end:
            raise ValueError("Start time must be before end time")
        new_booking = Booking(start=start, end=end, user=user)
        for existing in self._schedule[box]:
            if existing.overlaps(new_booking):
                raise ValueError("Time slot already booked")
        self._schedule[box].append(new_booking)
        self._schedule[box].sort()  # Keep bookings ordered by start time
        return new_booking

    def cancel(self, booking: Booking, box: str) -> None:
        """Cancel an existing booking."""
        if box not in self.boxes:
            raise ValueError(f"Unknown box: {box}")
        try:
            self._schedule[box].remove(booking)
        except ValueError:
            raise ValueError("Booking not found") from None

    def schedule_for_box(self, box: str) -> List[Booking]:
        """Return list of bookings for a box."""
        if box not in self.boxes:
            raise ValueError(f"Unknown box: {box}")
        return list(self._schedule[box])

# Default boxes for the office
DEFAULT_BOXES = [f"Box {i}" for i in range(1, 9)]

if __name__ == "__main__":
    # Simple demonstration
    system = BookingSystem(DEFAULT_BOXES)
    now = datetime.now()
    booking = system.reserve("alice", "Box 1", now, now.replace(hour=now.hour + 1))
    print("Reserved:", booking)
    print("Schedule for Box 1:", system.schedule_for_box("Box 1"))
