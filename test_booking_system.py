from datetime import datetime, timedelta

import pytest

from booking_system import BookingSystem, DEFAULT_BOXES

@pytest.fixture
def system():
    return BookingSystem(DEFAULT_BOXES)

def test_successful_booking(system):
    start = datetime(2023, 1, 1, 10)
    end = start + timedelta(hours=1)
    booking = system.reserve("user1", "Box 1", start, end)
    assert booking.user == "user1"
    assert system.schedule_for_box("Box 1") == [booking]

def test_overlapping_booking_fails(system):
    start = datetime(2023, 1, 1, 10)
    end = start + timedelta(hours=1)
    system.reserve("user1", "Box 1", start, end)
    with pytest.raises(ValueError):
        system.reserve("user2", "Box 1", start + timedelta(minutes=30), end + timedelta(minutes=30))

def test_cancel_booking(system):
    start = datetime(2023, 1, 1, 10)
    end = start + timedelta(hours=1)
    booking = system.reserve("user1", "Box 1", start, end)
    system.cancel(booking, "Box 1")
    assert system.schedule_for_box("Box 1") == []
