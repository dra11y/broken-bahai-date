module BahaiDate
  class BahaiDate
    AYYAM_I_HA = -1

    attr_reader :weekday, :day, :month, :year, :gregorian_date

    def initialize(params)
      params[:use_sunset] = true if params[:use_sunset].nil?
      @use_sunset = params[:use_sunset]

      if params[:date].respond_to?(:time_zone)
        @tz = params[:tz] || params[:date].try(:time_zone).try(:name)
      end

      @logic = Logic.new(tz: @tz, lat: params[:lat], lng: params[:lng])

      if params[:date]
        @gregorian_date = params[:date]
        year, month, day = from_gregorian
        @year = Year.new(year)
        @month = Month.new(month)
        @day = Day.new(day)
      elsif params[:year] && params[:month] && params[:day]
        @year = Year.new(params[:year])
        @month = Month.new(params[:month])
        @day = Day.new(params[:day])
        validate_ayyam_i_ha
        @gregorian_date = to_gregorian
      else
        fail ArgumentError, 'Invalid arguments. Use a hash with :date or with :year, :month, and :day.'
      end
      @weekday = Weekday.new(weekday_from_gregorian)
    end

    def occasions
      OccasionFactory.new(@year.bahai_era, @month.number, @day.number).occasions
    end

    def to_s
      "#{@year.bahai_era}.#{@month.number}.#{@day.number}"
    end

    def long_format
      "#{@weekday.html} #{@day.number} #{@month.html} #{@year.bahai_era} B.E."
    end

    def short_format
      "#{@day.number} #{@month} #{@year.bahai_era}"
    end

    def +(val)
      self.class.new(date: @gregorian_date + val, use_sunset: @use_sunset)
    end

    def -(val)
      self.class.new(date: @gregorian_date - val, use_sunset: @use_sunset)
    end

    def utc_date(date = @gregorian_date)
      date.respond_to?(:utc) ? date.utc.to_date : date
    end

    def sunset_time
      @logic.sunset_time_for(utc_date)
    end

    def next_sunset_time
      @logic.sunset_time_for(utc_date + 1.day)
    end

    private

    def validate_ayyam_i_ha
      fail ArgumentError, "'#{@day.number}' is not a valid day for Ayyam-i-Ha in the year #{@year.bahai_era}" if @month.number == AYYAM_I_HA && @day.number > ayyam_i_ha_days
    end

    def ayyam_i_ha_days(year = @year.bahai_era)
      @logic.leap?(year) ? 5 : 4
    end

    def to_gregorian
      year_gregorian = @year.bahai_era + 1844 - 1
      nawruz = @logic.nawruz_for(year_gregorian)
      nawruz + days_from_nawruz
    end

    def from_gregorian
      nawruz = @logic.nawruz_for(@gregorian_date.year)

      year = @gregorian_date.year - 1844
      if (@use_sunset && @gregorian_date >= @logic.sunset_time_for(nawruz)) ||
         (!@use_sunset && @gregorian_date.to_date >= nawruz)
        year += 1
        days = (@gregorian_date.to_date - nawruz).to_i
      else
        days = (@gregorian_date.to_date - @logic.nawruz_for(@gregorian_date.year - 1)).to_i
      end

      if @use_sunset
        current_sunset = sunset_time
        days += 1 if @gregorian_date > current_sunset &&
                    @gregorian_date.to_date == current_sunset.to_date
      end

      # determine day and month, taking into account ayyam-i-ha
      if days >= 342
        if days < (342 + ayyam_i_ha_days(year))
          month = AYYAM_I_HA
          day = days - 342
        else
          month = 19
          day = days - (342 + ayyam_i_ha_days(year))
        end
      else
        month, day = (days).divmod(19)
        month += 1
      end
      day += 1
      [year, month, day]
    end

    def weekday_from_gregorian
      # saturday (6 in ruby) is the first day of the week
      wday = @gregorian_date.wday == 6 ? 1 : @gregorian_date.wday + 2
      current_sunset = sunset_time
      wday += 1 if @gregorian_date > current_sunset &&
                   @gregorian_date < current_sunset.end_of_day
      wday == 7 ? 7 : wday % 7
    end

    def days_from_nawruz
      days = @day.number - 1
      full_months = @month.number - 1
      full_months = 18 if @month.number == AYYAM_I_HA
      days += full_months * 19
      days += ayyam_i_ha_days if @month.number == 19
      days
    end
  end
end
