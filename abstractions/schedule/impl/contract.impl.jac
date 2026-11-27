impl cron_fields(at: str) -> list[list[int]] {
    parts = at.split();
    if len(parts) != 5 {
        raise ValueError(
            "a time to run at is five fields: minute, hour, day of the month, month and day of the week",
        );
    }
    days_of_week = cron_field(parts[4], 0, 7, "day of the week");
    return [
        cron_field(parts[0], 0, 59, "minute"),
        cron_field(parts[1], 0, 23, "hour"),
        cron_field(parts[2], 1, 31, "day of the month"),
        cron_field(parts[3], 1, 12, "month"),
        sorted(set([0 if d == 7 else d for d in days_of_week])),
    ];
}

impl cron_field(text: str, low: int, high: int, what: str) -> list[int] {
    out: set[int] = set();
    for item in text.split(",") {
        (span, _, stride) = item.partition("/");
        step = 1;
        if stride != "" {
            if not stride.isdecimal() or int(stride) == 0 {
                raise ValueError(f"the {what}'s step '{stride}' is not a number more than 0");
            }
            step = int(stride);
        }
        first = low;
        last = high;
        if span != "*" {
            (a, dash, b) = span.partition("-");
            if not a.isdecimal() or (dash != "" and not b.isdecimal()) {
                raise ValueError(f"the {what} '{item}' is not *, a number, or a range of two");
            }
            first = int(a);
            last = int(b) if dash != "" else (high if stride != "" else first);
            if first < low or last > high or first > last {
                raise ValueError(f"the {what} '{item}' is outside {low} to {high}");
            }
        }
        for v in range(first, last + 1, step) {
            out.add(v);
        }
    }
    return sorted(out);
}

impl next_at(at: str, after: float) -> float {
    fields = cron_fields(at);
    (minutes, hours, days, months, weekdays) = (
        fields[0],
        fields[1],
        fields[2],
        fields[3],
        fields[4],
    );
    any_day = len(days) == 31;
    any_weekday = len(weekdays) == 7;
    utc = datetime.timezone.utc;
    start = datetime.datetime.fromtimestamp(float(int(after // 60) * 60 + 60), utc);
    day = start.date();
    first_minute = start.hour * 60 + start.minute;
    for _ in range(366 * 8) {
        on_day = day.day in days;
        on_weekday = (day.weekday() + 1) % 7 in weekdays;
        matched = on_day and on_weekday;
        if any_day and not any_weekday {
            matched = on_weekday;
        } elif any_weekday and not any_day {
            matched = on_day;
        } elif not any_day and not any_weekday {
            matched = on_day or on_weekday;
        }
        if day.month in months and matched {
            for h in hours {
                for m in minutes {
                    if h * 60 + m >= first_minute {
                        return datetime.datetime(
                            day.year, day.month, day.day, h, m, tzinfo=utc
                        ).timestamp();
                    }
                }
            }
        }
        day = day + datetime.timedelta(days=1);
        first_minute = 0;
    }
    raise ValueError(f"'{at}' names no minute that comes");
}
