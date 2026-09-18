# TwoDo

TwoDo models personal tasks and the calendar time reserved to complete them.

## Language

**Recurring task**:
A task that belongs to a recurrence series and carries a recurrence rule to its successor.
_Avoid_: Repeating reminder, repeating template

**Occurrence**:
One independently completable task in a recurrence series.
_Avoid_: Instance, repetition

**Recurrence rule**:
The cadence that determines the next eligible future occurrence.
_Avoid_: Repeat setting, schedule

**Successor**:
The single future occurrence created when a recurring occurrence is first completed.
_Avoid_: Copy, duplicate

**Recurrence series**:
The chain of occurrences connected by the same recurring intent.
_Avoid_: Recurring task group

**Reminder rule**:
A task preference that describes when an alert should occur relative to its due day or time block.
_Avoid_: Notification, alarm

**Notification**:
A concrete device alert produced from a reminder rule.
_Avoid_: Reminder rule
