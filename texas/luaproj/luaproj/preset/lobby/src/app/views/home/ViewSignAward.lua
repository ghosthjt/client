local GameConfig = require("app.common.GameConfig")
local UIHelper = require("app.common.UIHelper")
local ViewSignAward = class("ViewSignAward", cc.mvc.ViewBase)

function ViewSignAward:ctor(data)

print("==============ViewSignAward ===",data.itemNumber,data.coinNumber)
    ViewSignAward.super.ctor(self)

    local  csbnode = cc.CSLoader:createNode("cocostudio/home/SignGot.csb")
        :addTo(self)
       
    self.BG = UIHelper.seekNodeByName(csbnode,"Img_bg")
    self.BG:setScale(0.01)
    ------------------test data----------------------
   self.weekData =3
    
    self:selectIcon(data)
    
    self.weekAward = UIHelper.seekNodeByName(csbnode,"Img_week_award")
    local img_str = string.format("cocostudio/home/image/sign/sign_get%d.png",self.weekData)  
    self.weekAward:loadTexture(img_str)
    local Atl_weekcoin_number = UIHelper.seekNodeByName(csbnode,"AtlasLabel_week_cn")
    Atl_weekcoin_number:setString(string.format("%04d",data.coinNumber))

    self.weekAward1 = UIHelper.seekNodeByName(csbnode,"Img_week_award_1")
   
    self.weekAward1:setVisible(false)

    self.Atl_weekcoin_number1 = UIHelper.seekNodeByName(csbnode,"AtlasLabel_week_cn_1")

    
    local btn_closex = UIHelper.seekNodeByName(csbnode,"Button_close")
    btn_closex:addTouchEventListener(function (ref, t)
        if t == ccui.TouchEventType.ended then 
           self:removeSelf()
       end 
     end)

    
end

function ViewSignAward:onEnter()
    ViewSignAward.super.onEnter(self)
    self:actionEnter()
end

function ViewSignAward:actionEnter()
   self.BG:runAction(cc.EaseBackInOut:create(cc.ScaleTo:create(0.15, 1)))
end

function ViewSignAward:onExit()
   self.BG:runAction(
        cc.Sequence:create(
            cc.EaseBackInOut:create(
                cc.ScaleTo:create(0.15,0.01)
            ),
            cc.CallFunc:create(function()
                self:removeSelf() 
            end)
        )
   )
end

function ViewSignAward:addAward(data)
    
    self:selectIcon(data)
    local awardP = cc.p(self.weekAward:getPosition())
    self.weekAward:setPosition(awardP.x-105,awardP.y)
    self.weekAward1:setVisible(true)
    self.weekAward1:setPosition(awardP.x+105,awardP.y)    
    local img_str1 = string.format("cocostudio/home/image/sign/sign_get%d.png",self.weekData) 
    self.weekAward1:loadTexture(img_str1)
    self.Atl_weekcoin_number1:setString(string.format("%d",data.coinNumber))

end

--���ݽ������ͼ
function ViewSignAward:selectIcon(data)
    self.weekData = 3
    if data.coinNumber >3888 then 
    self.weekData = 5
    elseif data.coinNumber> 6888 then
    self.weekData = 7
    end 
end

return ViewSignAward