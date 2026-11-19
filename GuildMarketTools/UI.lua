local M=GuildMarketTools
local U={}; M.UI=U
local font=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
function U.Text(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(font,size or 13); f:SetTextColor(.87,.91,.94); f:SetJustifyH("LEFT")
    return f
end
local function fill(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
function U.Button(b)
    if b.gmtStyled then return b end; b.gmtStyled=true
    if b.Left then b.Left:Hide(); b.Middle:Hide(); b.Right:Hide() end
    b:SetNormalTexture(""); b:SetPushedTexture(""); b:SetDisabledTexture("")
    fill(b,.14,.19,.23)
    local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetColorTexture(.3,.75,.78,.15); b:SetHighlightTexture(h)
    b:SetNormalFontObject("GameFontHighlight"); b:SetDisabledFontObject("GameFontDisable")
    return b
end
function U.Window(name)
    local f=CreateFrame("Frame",name,UIParent)
    fill(f,.055,.075,.095,.99)
    local band=f:CreateTexture(nil,"BACKGROUND"); band:SetPoint("TOPLEFT"); band:SetPoint("TOPRIGHT"); band:SetHeight(63); band:SetColorTexture(.095,.125,.15,1)
    f.TitleText=U.Text(f,17); f.TitleText:SetPoint("TOPLEFT",18,-10)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-3,-3)
    close:SetScript("OnClick",function() f:Hide() end)
    f:SetClampedToScreen(true)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if type(w)=="number" and type(h)=="number" then f:SetScale(math.min(1,(w-20)/1160,(h-20)/680)) end
    return f
end
function U.Tabs(panel,active)
    for _,child in ipairs({panel:GetChildren()}) do
        if child:GetObjectType()=="Button" and child.GetText and child:GetText() and child:GetText()~="" then
            U.Button(child)
            local text=child:GetText()
            if text=="Deals" or text=="History" or text=="Watchlist" or text=="Ledger" or text=="Settings" or text=="Vendor" or text=="Professions" then
                child:SetAlpha(text==active and 1 or .65)
                if child:GetFontString() then child:GetFontString():SetTextColor(text==active and .4 or .87,text==active and .92 or .91,text==active and .88 or .94) end
            end
        end
    end
end
function U.Headers(parent,columns,y,callback)
    parent.gmtHeaders=parent.gmtHeaders or {}
    local x=0
    for i,c in ipairs(columns) do
        local b=parent.gmtHeaders[i]
        if not b then b=CreateFrame("Button",nil,parent); b.text=U.Text(b,12); parent.gmtHeaders[i]=b end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",16+x,y); b:SetSize(c[2],26)
        b.text:ClearAllPoints(); b.text:SetPoint("LEFT",6,0); b.text:SetWidth(c[2]-12); b.text:SetJustifyH(i==1 and "LEFT" or "RIGHT"); b.text:SetText(c[1]); b.text:SetTextColor(.4,.86,.84)
        b:SetScript("OnClick",function() if callback then callback(i) end end); b:Show(); x=x+c[2]
    end
end
function U.Row(parent,widgets,i,columns,values,selected)
    local b=widgets[i]
    if not b then
        b=CreateFrame("Button",nil,parent); b.cells={}; b.bg=fill(b,.11,.15,.18)
        local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetColorTexture(.35,.7,.75,.13); b:SetHighlightTexture(h); widgets[i]=b
    end
    b:ClearAllPoints(); b:SetPoint("TOPLEFT",0,-(i-1)*32)
    b.bg:SetColorTexture(selected and .12 or .10,selected and .26 or .13,selected and .29 or .16,selected and 1 or i%2==0 and 1 or .35)
    local x=0
    for n,c in ipairs(columns) do
        local f=b.cells[n]; if not f then f=U.Text(b,13); b.cells[n]=f end
        f:ClearAllPoints(); f:SetPoint("LEFT",x+6,0); f:SetSize(c[2]-12,28); f:SetJustifyH(n==1 and "LEFT" or "RIGHT"); f:SetWordWrap(false); f:SetText(values[n] or "--"); f:Show(); x=x+c[2]
    end
    for n=#columns+1,#b.cells do b.cells[n]:Hide() end
    b:SetSize(x,31); b:Show(); return b
end
function U.Sort(rows,column,descending,value)
    table.sort(rows,function(a,b)
        local av,bv=value(a,column),value(b,column)
        if av==nil then return false end
        if bv==nil then return true end
        if av==bv then return tostring(a.id or a.name or a.recipe and a.recipe.id or "")<tostring(b.id or b.name or b.recipe and b.recipe.id or "") end
        if descending then return av>bv end; return av<bv
    end)
end

-- Bound frame creation even when a full scan contains thousands of items.
function U.Page(parent,rows,refresh)
    if not parent.gmtPager then
        local p={page=1}; parent.gmtPager=p
        local function button(text,x,delta)
            local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(65,24); b:SetPoint("BOTTOMRIGHT",x,10); b:SetText(text); U.Button(b)
            b:SetScript("OnClick",function() p.page=p.page+delta; if parent.gmtScroll then parent.gmtScroll:SetVerticalScroll(0) end; refresh() end); return b
        end
        p.previous=button("Previous",-185,-1); p.next=button("Next",-16,1)
        p.label=U.Text(parent,12); p.label:SetPoint("BOTTOMRIGHT",-88,16); p.label:SetWidth(85); p.label:SetJustifyH("CENTER")
    end
    local p=parent.gmtPager; local pages=math.max(1,math.ceil(#rows/100)); p.page=math.max(1,math.min(p.page,pages))
    p.previous:SetEnabled(p.page>1); p.next:SetEnabled(p.page<pages); p.label:SetText(p.page.." / "..pages)
    local result={}; local offset=(p.page-1)*100
    for i=offset+1,math.min(#rows,offset+100) do result[#result+1]=rows[i] end
    return result,offset
end
