import Logging, Dates
export ModelLogger, shouldlog, min_enabled_level, catch_exceptions, handle_message


# -------------------------------------------------------------------------------------
# Custom LogLevels

const Diagnostic = Logging.LogLevel(-500)  # Sits between Debug and Info
const Setup = Logging.LogLevel(500)

# -------------------------------------------------------------------------------------
# Custom Logging Macros

macro diagnostic( msg ) @Logging.logmsg Diagnostic msg end
macro setup( msg ) @Logging.logmsg Setup msg end

# ------------------------------------------------------------------------------------
# ModelLogger
_model_logger_docs = """

    ModelLogger(stream::IO, level::LogLevel)

Based on Logging.SimpleLogger it tries to log all messages in the following format

    message --- [dd/mm/yyyy HH:MM:SS] log_level source_file:line_number

The logger will handle any message from @debug up.
"""
struct ModelLogger <: Logging.AbstractLogger
    stream::IO
    min_level::Logging.LogLevel
    message_limits::Dict{Any,Int}
end
ModelLogger(stream::IO=stderr, level=Diagnostic) = ModelLogger(stream, level, Dict{Any,Int}())

Logging.shouldlog(logger::ModelLogger, level, _module, group, id) = get(logger.message_limits, id, 1) > 0

Logging.min_enabled_level(logger::ModelLogger) = logger.min_level

Logging.catch_exceptions(logger::ModelLogger) = false

function level_to_string(level::Logging.LogLevel)
    if level == Diagnostic "Diagnostic"
    elseif level == Setup "Setup"
    elseif level == Logging.Warn "Warning"
    else string(level)
    end
end

function Logging.handle_message(logger::ModelLogger, level, message, _module, group, id, filepath, line; maxlog = nothing, kwargs...)
    if maxlog !== nothing && maxlog isa Integer
        remaining = get!(logger.message_limits, id, maxlog)
        logger.message_limits[id] = remaining - 1
        remaining > 0 || return
    end
    buf = IOBuffer()
    iob = IOContext(buf, logger.stream)
    level_name = level_to_string(level)
    module_name = something(_module, "nothing")
    file_name = something(filepath, "nothing")
    line_number = something(line, "nothing")
    msg_timestamp = Dates.format(Dates.now(), "[dd/mm/yyyy HH:MM:SS]")
    formatted_message = "$message --- $msg_timestamp $level_name $file_name:$line_number"
    println(iob, formatted_message)
    write(logger.stream, take!(buf))
    nothing
end
