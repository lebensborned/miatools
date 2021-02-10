-- This file is part of broadcaster library
-- Licensed under MIT License
-- Copyright (c) 2019 Ranx
-- https://github.com/r4nx/broadcaster
-- Version 0.2.0

local handlers = {}

local logger = require 'log'
logger.usecolor = false
logger.level = 'debug'

local proto = require 'broadcaster.proto'
local utils = require 'broadcaster.utils'
local encoder = require 'broadcaster.encoder'
local charset = require 'broadcaster.charset'
local magic = require 'broadcaster.magic'

local inspect = require 'inspect'

-- Args:
--    handlerId <string> - unique handler id
--    callback <function> - callback function
--    rawData <bool> [optional] - do not decode data before passing to callback
function EXPORTS.registerHandler(handlerId, callback, rawData)
    -- Doing some check in advance to avoid undefined behavior
    if type(handlerId) ~= 'string' or not encoder.check(handlerId, charset.MESSAGE_ENCODE) then
        error(('invalid handler id ("%s")'):format(handlerId))
    end
    if handlers[handlerId] ~= nil then
        error(('handler id collision: handler "%s" has been already registered'):format(handlerId))
    end    
    if type(callback) ~= 'function' then
        error(('callback object is not a function (handler id "%s")'):format(handlerId))
    end

    handlers[handlerId] = {callback, rawData}
    
end

-- Args:
--    handlerId <string> - handler id to unregister
-- Returns:
--    bool - true if unregistered successfully
function EXPORTS.unregisterHandler(handlerId)
    if handlers[handlerId] ~= nil then
        handlers[handlerId] = nil
       
        return true
    end
    return false
end

local function bitsToBitStream(bits)
    local bs = raknetNewBitStream()
    for _, bValue in ipairs(bits) do
        raknetBitStreamWriteBool(bs, bValue == 1 and true or false)
    end
    return bs
end

-- Args:
--    message <string> - message to send
--    handlerId <string> - remote handler id
function EXPORTS.sendMessage(message, handlerId)
    if type(message) ~= 'string' or not encoder.check(message, charset.MESSAGE_ENCODE) then
        error(('invalid message ("%s")'):format(message))
    end
    if type(handlerId) ~= 'string' or not encoder.check(handlerId, charset.MESSAGE_ENCODE) then
        error(('invalid handler id ("%s")'):format(handlerId))
    end

    local encodedMessage = encoder.encode(message, charset.MESSAGE_ENCODE)
    local encodedHandlerId = encoder.encode(handlerId, charset.MESSAGE_ENCODE)

   

    local packets = proto.sendData(encodedMessage, encodedHandlerId)
    for _, p in ipairs(packets) do
        local bs = bitsToBitStream(p)
        raknetBitStreamSetWriteOffset(bs, 16)
        raknetSendRpc(magic.RPC_OUT, bs)
        raknetDeleteBitStream(bs)
    end
end

function EXPORTS._printHandlers()
    print('Handlers:')
    for handlerId, handlerData in pairs(handlers) do
        print(handlerId, inspect(handlerData))
    end
end

function EXPORTS._printSessions()
    print('Sessions:\n' .. inspect(proto.getSessions()))
end

local function bitStreamToBits(bs)
    local bits = {}
    for _ = 1, raknetBitStreamGetNumberOfUnreadBits(bs) do
        bits[#bits + 1] = raknetBitStreamReadBool(bs) and 1 or 0
    end
    return bits
end

local function sessionHandler(session)
   
    local handlerId = encoder.decode(session.handlerId, charset.MESSAGE_DECODE)
    
    local handler, rawData = unpack(handlers[handlerId] or {})
    if handler ~= nil then
        if rawData then
            handler(session.data)
        else
            handler(encoder.decode(session.data, charset.MESSAGE_DECODE))
        end
    else
        
    end
end

local function rpcHandler(rpcId, bs)
    if rpcId == magic.RPC_IN and utils.tableLength(handlers) > 0 then
        raknetBitStreamResetReadPointer(bs)

        local bits = bitStreamToBits(bs)
        

        if #bits == magic.PACKETS_LEN then
            proto.processPacket(bits, sessionHandler)
        else
            
        end
    end
end

function main()
   
    addEventHandler('onReceiveRpc', rpcHandler)
    wait(-1)
end
