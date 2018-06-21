-- local functions
local CreateFrame = CreateFrame;
local min = min;
local max = max;

-- local variables
local _;

function Gnosis:CreateStatusBar(parent)
	local sbf = CreateFrame("Frame", nil, parent);

	sbf.cV = 0;
	sbf.minV = 0;
	sbf.maxV = 1;
	sbf.curV = sbf.cV - sbf.minV;
	sbf.totV = sbf.maxV - sbf.minV;
	sbf.divV = sbf.curV / sbf.totV;
	sbf.bInv = false;
	sbf.size = 10;
	sbf:SetHeight(sbf.size);
	sbf:SetWidth(sbf.size);

	sbf.t = sbf:CreateTexture(nil, "BORDER");
	sbf.ag, sbf.an = Gnosis:RAG(sbf.t);

	sbf.SetMinMaxValues = function(this, minval, maxval)
		this.minV = min(minval,maxval);
		this.maxV = max(minval,maxval);
		this.totV = this.maxV - this.minV;
		this.divV = this.curV / this.totV;
		this:Update(this);
	end

	sbf.SetOrientation = function(this, orientation, bInvDir)
		this.t:ClearAllPoints();
		this.bInv = bInvDir;
		if(orientation == "VERTICAL") then
			this.orient = "VERTICAL";
			if(this.bInv) then
				this.t:SetPoint("TOPLEFT");
				this.t:SetPoint("TOPRIGHT");
			else
				this.t:SetPoint("BOTTOMLEFT");
				this.t:SetPoint("BOTTOMRIGHT");
			end
		else
			this.orient = "HORIZONTAL";
			if(this.bInv) then
				this.t:SetPoint("TOPRIGHT");
				this.t:SetPoint("BOTTOMRIGHT");
			else
				this.t:SetPoint("TOPLEFT");
				this.t:SetPoint("BOTTOMLEFT");
			end
		end

		this:SizeChanged(this);
		this:Update(this);
	end

	sbf.SetValue = function(this, value)
		this.cV = min(max(this.minV+0.000001, value), this.maxV);
		this.curV = this.cV - this.minV;
		this.divV = this.curV / this.totV;
		this:Update(this);
	end

	sbf.SetStatusBarTexture = function(this, tex)
		this.t:SetTexture(tex);
	end

	sbf.SetStatusBarColor = function(this, r, g, b, a)
		this.t:SetVertexColor(r, g, b, a);
	end

	sbf.SizeChanged = function(this)
		if(this.orient == "VERTICAL") then
			this.size = this:GetHeight();
		else
			this.size = this:GetWidth();
		end
		this:Update(this);
	end

	sbf.Update = function(this)
		if(this.orient == "VERTICAL") then
			this.t:SetHeight(this.size * this.divV);
			if(this.bInv) then
				this.t:SetTexCoord(0, 1, 0, this.divV);
			else
				this.t:SetTexCoord(0, 1, 1-this.divV, 1);
			end
		else
			this.t:SetWidth(this.size * this.divV);
			if(this.bInv) then
				this.t:SetTexCoord(this.divV, 0, 0, 1);
			else
				this.t:SetTexCoord(0, this.divV, 0, 1);
			end
		end
	end

	sbf:SetScript("OnSizeChanged", sbf.SizeChanged);
	sbf:Update(sbf);
	return sbf;
end
