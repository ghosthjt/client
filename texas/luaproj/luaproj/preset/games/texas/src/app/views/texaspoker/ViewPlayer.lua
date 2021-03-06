local utils = require("utils")
local UIHelper = require("app.common.UIHelper")
local SoundUtils = require("app.common.SoundUtils")
local NativeFunctions = require("app.common.NativeFunctions")
local ViewCard = require("app.views.texaspoker.ViewCard")
local TexasPokerConfig = require("app.models.TexasPokerConfig")
local ResItemWidget = require("app.views.common.ResItemWidget")
local CMD = require("app.net.CMD")
local GameConfig = require("app.common.GameConfig")
local ViewPlayer = class("ViewPlayer", function()
 	return display.newNode()
end)

ViewPlayer.TIMER_COLORS = {cc.c3b(0, 255, 0), cc.c3b(255, 242, 93), cc.c3b(255, 78, 0)}

function ViewPlayer:ctor(clipos, isclone)
	self:enableNodeEvents()
	self.myCards = {}
	self.clipos = clipos

	if clipos >= 5 then
		self.isRight = true;
	else
		self.isRight = false;
	end

	if not isclone then
		self.evt = addListener(self, "NET_MSG", handler(self, self.onMsg));
	end

	self.csbnode = cc.CSLoader:createNode("cocostudio/game/PlayerNode.csb")
	self.csbnode:addTo(self)

	local used = UIHelper.seekNodeByName(self.csbnode, "used");
	used:setVisible(false);

	-- 自己的下注UI位置调整
	self.img_Head = UIHelper.seekNodeByName(self.csbnode, "Image_Head")
	self.text_Nickname = UIHelper.seekNodeByName(self.csbnode, "Text_Nickname")
	self.text_Gold = UIHelper.seekNodeByName(self.csbnode, "AtlasLabel_Gold")
	self.Node_Pet = used:getChildByName("Node_Bet")
	self.img_Card_1 = UIHelper.seekNodeByName(self.csbnode, "Image_CardIcon_1")
	self.img_Card_2 = UIHelper.seekNodeByName(self.csbnode, "Image_CardIcon_2")
	self.img_Mask = UIHelper.seekNodeByName(self.csbnode, "Image_Mask")
	self.img_Operate = UIHelper.seekNodeByName(self.csbnode, "Image_Operate")
	self.img_Banker = UIHelper.seekNodeByName(self.csbnode, "Image_Banker")
	self.img_CardType = UIHelper.seekNodeByName(self.csbnode, "Image_CardType")
	self.Image_Winner = UIHelper.seekNodeByName(self.csbnode, "Image_Winner")

	self.timerProgress = cc.ProgressTimer:create(display.newSprite("cocostudio/game/image/zhujiemian_baixian.png"))
		:setReverseDirection(true)
		:move(0,0)
		:setVisible(false)
		:setPercentage(100)
		:addTo(self)
	
	used = UIHelper.seekNodeByName(self.csbnode, "empty");
	local btn = UIHelper.seekNodeByName(used, "Button_1");
	btn:addTouchEventListener(function(sender, state)
        APP.gc:sitDown(clipos);
    end)

	
	if self.isRight then
		local posy = self.img_Banker:getPositionY()
		local posx = self.img_Banker:getPositionX()
		self.img_Banker:setPosition(cc.p(-posx, posy))
	end
end

function ViewPlayer:setSitVisible(vis)
	local used = UIHelper.seekNodeByName(self.csbnode, "empty");
	local btn = UIHelper.seekNodeByName(used, "Button_1");
	if vis then
		btn:setVisible(true);
	else
		btn:setVisible(false);
	end
end

function ViewPlayer:clone()
	local newp = ViewPlayer.new(self.clipos, true);
	if self.usr then
	    newp:setUser(self.usr, true);
	end
	return newp;
end

function ViewPlayer:setUser(usr, isclone)
	self:setSitVisible(false);
	if not usr then 
		local used = UIHelper.seekNodeByName(self.csbnode, "used");
		used:setVisible(false);

		used = UIHelper.seekNodeByName(self.csbnode, "empty");
		used:setVisible(true);
		self:clear();
	else
		local used = UIHelper.seekNodeByName(self.csbnode, "used");
		used:setVisible(true);
		self.usr = usr
		self.uid = usr.uid
		self.timer_totalTime = 0
		self.timer_leftTime = 0
		self.myCards = {}

		local players = APP.GD.room_players
		local player = players:getPlayerByUid(self.uid)
		self.img_Head:loadTexture(string.format("image/%s", GameConfig:HeadIco(player.head_ico)))
		self.img_Head:addTouchEventListener(function(ref, t)
			if t == ccui.TouchEventType.ended then
				APP.gc:showPlayerInfoLayer(self.uid)
			end
		end)

		self.text_Nickname:setString(utils.trimUtf8String(player.uname, 5))

		self:updateGold(player.credits)

        self:createResItem()
		
		self:clear()
		self:setMaskStatus(true);

		if isclone then
			return;  
		end

		-- 是否有牌
		if player.cards and player.cards ~= "" then
			self:setDealedCardStatus(true)
			self:setMaskStatus(false);
		end
		-- 是否为庄家
		local room = APP.GD.game_room;
		if player.uid == room.banker_set then
			self:setBankerStatus(true)
		end
		-- 是否有操作
		if player.action and player.action ~= -1 then
			self:setOperateViewStatus(true, player.action)
			if player.action == TexasPokerConfig.ACTION_GIVEUP then
				self:setDealedCardStatus(false)
				self:setMaskStatus(true);
			elseif player.action == TexasPokerConfig.ACTION_ALLIN then
				if not self.allinAnim then
					self:showAllin()
				end
			end
		end
		-- 下的注
		if player.setbet and player.setbet > 0 then
			self:setBet(true, player.setbet)
		end
		-- 是否有请求操作
		if player.valid_op and player.valid_op ~= "" and player.time_left > 1.0 then
			self:setTimerStatus(true, player.time_left)
		end
	end
end
---背景图片，字体大小，
function ViewPlayer:createResItem()
    if not self.ResItem then 
        self.ResItem = ResItemWidget:create(45)
        self.Node_Pet:addChild(self.ResItem)

        self.ResItem:setBgTexture("cocostudio/game/image/zhujiemian_choumatoumingdi.png")
        self.ResItem:setResTexture("cocostudio/game/image/bet_small.png")
    end
end


function ViewPlayer:onEnter()
	printInfo("ViewPlayer:onEnter")
	-- body
end

function ViewPlayer:onExit()
	if self.timerHandle then
		scheduler.unscheduleGlobal(self.timerHandle)
		self.timerHandle = nil

		removeListener(self.evt);
	end
end

function ViewPlayer:updateGold(gold)
	local str, unit = utils.convertNumberShort(gold)
	self.text_Gold:setString(str)
end

-- show 是否显示
-- bet 下注数
-- isAction 是否需要飘筹码动画
function ViewPlayer:setBet(show, bet, isAction)
	local str = utils.convertNumberShort(tonumber(bet))
	if isAction then
		APP:getObject("ViewActions"):actionBetIn(
			self.uid, 
			cc.p(self.Node_Pet:getPositionX() - 38, self.Node_Pet:getPositionY()),
			function()
                self.Node_Pet:setVisible(show)
                self.ResItem:setString(str)
			end
		)
	else

        self.Node_Pet:setVisible(show)
        self.ResItem:setString(str)
	end
end

-- 隐藏筹码时动作
function ViewPlayer:hideBetAction(callback)
	APP:getObject("ViewActions"):actionBetToPool(
		self.uid,
		cc.p(self.Node_Pet:getPositionX() - 38, self.Node_Pet:getPositionY()),
		callback
	)
	SoundUtils.playEffect(SoundUtils.GameSound.CHIPFLYCHI)
end

function ViewPlayer:setTimerStatus(show, time)

	self:unschedule("self.timerHandle")

	if show then
		self.timer_leftTime = time
		self.timer_totalTime = time
		self.timerProgress.colorStatus = 1
	    self:updateTimerColor()
  		self:schedule(handler(self, self.timerHandler), 0.04, "self.timerHandle")
	else
		self.timer_leftTime = 0
		self.timer_totalTime = 0
		self.timerProgress:setPercentage(100)
		self.timerProgress.colorStatus = 1
	    self:updateTimerColor()
	end
	self.timerProgress:setVisible(show)
end

function ViewPlayer:timerHandler()
    if not self.timer_leftTime then return end;
	-- printInfo("self.timer_totalTime:%f, self.timer_leftTime:%f", self.timer_totalTime, self.timer_leftTime)
	self.timer_leftTime = self.timer_leftTime - 0.04
	self.timerProgress:setPercentage(100 - (self.timer_totalTime - self.timer_leftTime) / self.timer_totalTime * 100)
	if self.timer_leftTime <= 0 then
		self:setTimerStatus(false, 0)
		return
	end
	-- printInfo("Timer Left Time:%f", 100 - (self.timer_totalTime - self.timer_leftTime) / self.timer_totalTime * 100)
	local newColorStatus = 1
	if self.timer_leftTime > 4 then
		newColorStatus = 1
	elseif self.timer_leftTime > 2 and self.timer_leftTime <= 4 then
		newColorStatus = 2
	elseif self.timer_leftTime > 0 and self.timer_leftTime <= 2 then
		newColorStatus = 3
		local gameUser = APP.GD.GameUser
		if self.timer_leftTime == 4 and gameUser.uid == self.uid then
			-- 震动一下
			NativeFunctions.vibrate(1000)
		end
	end
	if self.timerProgress.colorStatus ~= newColorStatus then
		self.timerProgress.colorStatus = newColorStatus
	    self:updateTimerColor()
	end
end

function ViewPlayer:updateTimerColor()
	self.timerProgress:getSprite():setColor(ViewPlayer.TIMER_COLORS[self.timerProgress.colorStatus])
end

function ViewPlayer:setMaskStatus(show)
	self.img_Mask:setVisible(show)
end

-- 显示有牌标识，show是否显示，isAction是否需要动画
function ViewPlayer:setDealedCardStatus(show, isAction)
	
	if not isAction then
		self.img_Card_1:setVisible(show)
		self.img_Card_2:setVisible(show)
		return
	end
	
	self:setMaskStatus(not show);

	--发牌
	if show then
		local imgCards = {self.img_Card_1, self.img_Card_2}
		for i = 1, #imgCards do
			local img_Card = imgCards[i]
			img_Card:setVisible(false); --先把自己藏起来

			local targetPosx, targetPosy = img_Card:getPositionX(), img_Card:getPositionY()
			local ptfrom = self:convertToNodeSpace(cc.p(display.cx, display.cy))
			local fly = img_Card:clone();
			fly:setVisible(true)
			fly:setPosition(ptfrom)
			fly:addTo(self)

			fly:runAction(
				cc.Sequence:create(
					cc.DelayTime:create(i * 0.3),
					cc.CallFunc:create(function()
						SoundUtils.playFanpai(1)
					end),
					cc.EaseOut:create(cc.MoveTo:create(0.3, cc.p(targetPosx, targetPosy)), 2),
					cc.CallFunc:create(function()
						img_Card:setVisible(true)
						fly:removeSelf();
					end)
				))
		end
	--弃牌
	else
		local imgCards = {self.img_Card_1, self.img_Card_2}
		for i = 1, #imgCards do
			local img_Card = imgCards[i]
			img_Card:setVisible(false); --先把自己藏起来

			local targetPosx, targetPosy = img_Card:getPositionX(), img_Card:getPositionY()
			local flyto = self:convertToNodeSpace(cc.p(display.cx, display.cy))
			local fly = img_Card:clone(); --防止连续执行两次的情况下,出现位置问题,不动原本图的位置才能解决问题

			fly:setVisible(true)
			fly:setPosition(cc.p(targetPosx, targetPosy))
			fly:addTo(self)

			fly:runAction(
				cc.Sequence:create(
					cc.Spawn:create(
						cc.FadeOut:create(0.3),
						cc.EaseSineOut:create(
							cc.MoveTo:create(0.3, flyto)
					)),
				cc.CallFunc:create(function()
						img_Card:setVisible(false)
						fly:removeSelf();
					end)
				))
		end
	end
end

function ViewPlayer:setBankerStatus(show)
	self.img_Banker:setVisible(show)
end

function ViewPlayer:showAllin()
	local spr, act = UIHelper.newAnimation(20, self, 
	function(i) return string.format("QY_OE_01__%05d.png", i - 1)  end);
	spr:setOpacity(0);

	spr:runAction(cc.Sequence:create(cc.FadeIn:create(0.5),
	 cc.CallFunc:create(function() SoundUtils.playEffect(SoundUtils.GameSound.ALLINEFF); end)));
	self.allinAnim = spr;

end

function ViewPlayer:setOperateViewStatus(show, op)
	if show then
		self.img_Operate:loadTexture(string.format("cocostudio/game/image/game_state_%d.png", op))
		self.img_Operate:setVisible(true)
		self.text_Nickname:setVisible(false)
		-- 弃牌头像变灰
		if op == TexasPokerConfig.ACTION_GIVEUP then
			self:setMaskStatus(true)
		elseif op == TexasPokerConfig.ACTION_ALLIN then
			self:showAllin()
		end
	else
		local players = APP.GD.room_players
		local player = players:getPlayerByUid(self.uid)
		-- 弃牌操作不要清除状态
		if player and player.action ~= TexasPokerConfig.ACTION_GIVEUP and player.action ~= TexasPokerConfig.ACTION_ALLIN then
			self.img_Operate:setVisible(false)
			self.text_Nickname:setVisible(true)
			self.img_CardType:setVisible(false)
		end
	end
end

-- 赢家显示手牌
function ViewPlayer:showCardsToOther()
	local players = APP.GD.room_players
	local player = players:getPlayerByUid(self.uid)
	local cs = string.split(player.cards, ",")
	for i = 1, #cs do
		if cs[i] ~= "" and cs[i] ~= "-1" then
			local card = ViewCard.new(tonumber(cs[i]))
			card:addTo(UIHelper.seekNodeByName(self.csbnode, "card" .. tostring(i)))

			if not player:isInBestCard(tonumber(cs[i])) then
				card:toGray()
			end
			table.insert(self.myCards, card)
		end
	end
	SoundUtils.playFanpai(1)

end

function ViewPlayer:clearMyCard()
	for _, card in pairs(self.myCards) do
		card:removeSelf()
	end
	self.myCards = {}
	self.img_Operate:setVisible(false)
	self.text_Nickname:setVisible(true)
	self.img_CardType:setVisible(false)
end

-- 显示牌型
function ViewPlayer:setCardTypeStatus(show, t)
	-- printInfo("setCardTypeStatus:%s, type:%s, uid:%s", tostring(show), tostring(t), self.uid)
	local gameUser = APP.GD.GameUser

	if show then
		self.img_CardType:loadTexture(string.format("cocostudio/game/image/card_type_%d.png", t))
		self.img_CardType:setVisible(true)
		self.text_Nickname:setVisible(false)
		self.Image_Winner:setVisible(true);

		if gameUser.uid ~= self.uid then
			self.img_Operate:setVisible(false)
			self.img_Head:setVisible(false)
			self.img_Card_1:setVisible(false)
			self.img_Card_2:setVisible(false)
		end
	else
		self.img_CardType:setVisible(false)
		self.text_Nickname:setVisible(true)
		self.img_CardType:setVisible(false)
		self.img_Head:setVisible(true)
		self.Image_Winner:setVisible(false);
	end
end

-- 自己是否下过注
function ViewPlayer:isBeted()
	return self.Node_Pet:isVisible()
end

function ViewPlayer:clear()
	local used = UIHelper.seekNodeByName(self.csbnode, "used");

	self.Node_Pet:setVisible(false)
	self.timerProgress:setVisible(false)
	self.img_Banker:setVisible(false)
	self.img_Mask:setVisible(false)
	self.Image_Winner:setVisible(false)

	self:setDealedCardStatus(false)
	self:clearMyCard()
	self:setCardTypeStatus(false)

	if self.allinAnim then
		self.allinAnim:runAction(cc.Sequence:create(cc.FadeOut:create(0.3), cc.RemoveSelf:create()));
		self.allinAnim = nil;
	end
end

function ViewPlayer:actionEnter(pos)

end

function ViewPlayer:actionExit(pos)
	
end
---------------------------chat 监听-------------------
function ViewPlayer:onMsg(fromServer, subCmd, content)
	if subCmd == CMD.GAME_CHAT_RESP then
        local msg = {
            fromId = content.from_uid_,
            nickName = content.nickname_,
            text = content.content_,
        }
        self:showChatContent(msg)
	end
end

function ViewPlayer:showChatContent(chat)
    if chat.fromId == self.uid then 
--       if true then 
        local players = APP.GD.room_players
	    local player = players:getPlayerByUid(chat.fromId)

        local chatNode = display.newNode()
			:addTo(self)

        local l,m = string.find(chat.text,"face_default_")
        local bFace = l == 1
        local textSize = nil
        local bg = nil

        if  self.isRight then 
            chatNode:setPosition(cc.p(-65,0))
            if bFace then 
                local faceImg = ccui.ImageView:create()
                faceImg:ignoreContentAdaptWithSize(false)
                faceImg:loadTexture(string.format("cocostudio/game/image/chat/face/%s.png",chat.text),ccui.TextureResType.localType)
                faceImg:align(display.RIGHT_CENTER ,-15 , 0)
                textSize = cc.size(40,40)
                faceImg:setContentSize(textSize)
                chatNode:addChild(faceImg,1)
            else
                local text_Content = cc.Label:createWithSystemFont(utils.checkStr(chat.text, 12), "Arial", 20)
	                    :addTo(chatNode, 1)
	            textSize = text_Content:getContentSize()
			    text_Content:align(display.RIGHT_CENTER ,-15 , 0)
--                text_Content:setColor(cc.c4b(10,10,10,255))

            end
		    bg = ccui.Scale9Sprite:create(cc.rect(16, 20, 16, 5), "cocostudio/game/image/chat/chat_bg_other.png")
			    :addTo(chatNode)
			    :align(display.RIGHT_CENTER ,0 , 0)
		    bg:setFlippedX(true)

		else
            chatNode:setPosition(cc.p(65,0))
            if bFace then 
                local faceImg = ccui.ImageView:create()
                faceImg:ignoreContentAdaptWithSize(false)
                faceImg:loadTexture(string.format("cocostudio/game/image/chat/face/%s.png",chat.text),ccui.TextureResType.localType)
                faceImg:align(display.LEFT_CENTER, 15,0)
                textSize = cc.size(40,40)
                faceImg:setContentSize(textSize)
                chatNode:addChild(faceImg,1)               
            else
                local text_Content = cc.Label:createWithSystemFont(utils.checkStr(chat.text, 12), "Arial", 20)
	                    :addTo(chatNode, 1)
                textSize = text_Content:getContentSize()
			    text_Content:align(display.LEFT_CENTER,15,0)

            end
    	    bg = ccui.Scale9Sprite:create(cc.rect(16, 20, 16, 5), "cocostudio/game/image/chat/chat_bg_other.png")
		    :addTo(chatNode)
		    :align(display.LEFT_CENTER,0,0)
            
        end
        bg:setContentSize(cc.size(textSize.width + 30,textSize.height + 20))

        chatNode:runAction(cc.Sequence:create(cc.DelayTime:create(2),cc.RemoveSelf:create()))
    end
end

return ViewPlayer