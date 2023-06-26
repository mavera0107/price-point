local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Promise = require(ReplicatedStorage.Packages.Promise)
local CreateLogger = require(ReplicatedStorage.Shared.CreateLogger)

local REWARD_SCORE_SOUND_TAG = "RewardScoreSound"

local logger = CreateLogger(script)

local function PercentageDistance(a, b)
    local distance = 1 - (math.abs(a - b) / math.max(a, b))
    return if distance == distance then distance else 1
end

local function Round(x)
    return math.floor(x + 0.5)
end

local function OrderScoresDescending(scores)
    local sorted = {}

    for userId, score in scores do
        table.insert(sorted, {userId, score})
    end

    table.sort(sorted, function(a, b)
        return a[2] > b[2]
    end)

    return sorted
end

local function PlaySoundsWithTag(tag: string, playbackSpeed: number?)
    for _, sound: Sound in CollectionService:GetTagged(tag) do
        if sound:IsA("Sound") then
            if playbackSpeed then
                sound.PlaybackSpeed = playbackSpeed
            end

            sound:Play()
        end
    end
end

local function RewardPoints(system)
    return Promise.new(function(resolve)
        local finalGuesses = system:GetGuesses()
        local scoreStateContainer = system:GetScoreStateContainer()
        local currentProduct = system:GetCurrentProduct()
        local price = currentProduct.PriceInRobux or currentProduct.Price or currentProduct.Robux or 0
        local waitTime = 0.5
        local playbackSpeed = 1
        logger.print("Old scores:", scoreStateContainer:GetAll())

        system:RevealGuesses()
        system:ResortScoreboards()
        task.wait(2)

        local function GiveOutRewards()
            local oldScores = scoreStateContainer:GetAll()

            -- Add any new guessers onto the scoreboard
            for userId in finalGuesses do
                if not oldScores[userId] then
                    oldScores[userId] = 0
                end
            end

            for _, value in OrderScoresDescending(oldScores) do
                local userId = value[1]
                local score = value[2]
                local guess = finalGuesses[userId]

                if not guess then
                    continue
                end

                local player = Players:GetPlayerByUserId(userId)

                if not player then
                    continue
                end

                local reward = 100 * PercentageDistance(guess, price)

                -- Prevent against NaN errors, as we have the potential to divide by zero here
                if reward ~= reward then
                    reward = 0
                end

                if price == guess then
                    reward = reward * 1.5
                end

                reward = Round(reward)

                if reward ~= 0 then
                    local newScore = score + reward
                    scoreStateContainer:Patch({
                        [userId] = newScore
                    })

                    logger.print(`Rewarded {player} with {reward}, new score is {newScore}`)
                    PlaySoundsWithTag(REWARD_SCORE_SOUND_TAG, playbackSpeed)
                    task.wait(waitTime)
                    playbackSpeed = math.min(playbackSpeed + 0.05, 1.3)
                    waitTime = math.max(waitTime - 0.05, 0.2)
                end
            end
        end

        GiveOutRewards()
        system:ResortScoreboards()
        logger.print("New scores:", scoreStateContainer:GetAll())
        task.wait(2)
        resolve(system:GetStateByName("NextRound"))
    end)
end

return RewardPoints