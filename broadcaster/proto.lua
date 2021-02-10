-- This file is part of broadcaster library
-- Licensed under MIT License
-- Copyright (c) 2019 Ranx
-- https://github.com/r4nx/broadcaster
-- Version 0.2.0

local proto = {}

local packet = require 'broadcaster.packet'
local utils = require 'broadcaster.utils'
local Session = require 'broadcaster.session'
local inspect = require 'inspect'

local logger = require 'log'
local sessions = {}

-- Args:
--    bin <table> - binary sequence
--    callback <function> - function to call when session is finished
--      (session is passed as first argument to callback)
function proto.processPacket(bin, callback)
    proto.collectOldSessions()
    local packetCode = utils.binToDec({unpack(bin, 1, 3)})

    packetProcessors = utils.switch({
        [packet.PACKETS_ID.START_TRANSFER] = function()
    
            local startPacket = packet.StartTransferPacket.unpack(bin)
            local sessionId = startPacket.sessionId

            if sessions[sessionId] ~= nil then
                sessions[sessionId] = nil
                
                return
            end

            sessions[sessionId] = Session()
            
        end,
        [packet.PACKETS_ID.DATA] = function()
           
            local result, returned = pcall(packet.DataPacket.unpack, bin)
            if not result then
               
                return
            end
            local sessionId = returned.sessionId

            local sess = sessions[sessionId]
            if sess ~= nil then
                sess:appendData(returned.data)
            else
                
            end
        end,
        [packet.PACKETS_ID.HANDLER_ID] = function()
           
            local result, returned = pcall(packet.HandlerIdPacket.unpack, bin)
            if not result then
               
                return
            end
            local sessionId = returned.sessionId

            local sess = sessions[sessionId]
            if sess ~= nil then
                sess:appendHandlerId(returned.handlerId)
            else
                
            end
        end,
        [packet.PACKETS_ID.STOP_TRANSFER] = function()
           
            local stopTransferPacket = packet.StopTransferPacket.unpack(bin)
            local sessionId = stopTransferPacket.sessionId

            local sess = sessions[sessionId]
            if sess ~= nil then
                sessions[sessionId] = nil
               
                callback(sess)
            else
               
            end
        end,
        default = function() logger.warn('cannot identify packet') end
    })

    packetProcessors:case(packetCode)
end

local function randomSessionId()
    math.randomseed(os.time() ^ 5)
    return math.random(0, 15)  -- 4 bit
end

-- Args:
--    data <table> - table of decimal numbers
--    handlerId <table> - encoded handler id
-- Returns:
--    Table of binary sequences
function proto.sendData(data, handlerId)
    local sessionId = randomSessionId()
    local packets = {packet.StartTransferPacket(sessionId):pack()}

    for _, handlerIdPart in ipairs(handlerId) do
        packets[#packets + 1] = packet.HandlerIdPacket(handlerIdPart, sessionId):pack()
    end

    for _, dataPart in ipairs(data) do
        packets[#packets + 1] = packet.DataPacket(dataPart, sessionId):pack()
    end

    packets[#packets + 1] = packet.StopTransferPacket(sessionId):pack()

    return packets
end

function proto.collectOldSessions()
    for sessionId, sess in pairs(sessions) do
        if os.time() - sess.lastUpdate > 30 then
            sessions[sessionId] = nil
           
        end
    end
end

function proto.getSessions()
    return sessions
end

return proto
