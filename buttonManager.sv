`timescale 1 ns / 1 ps
module buttonManager(
	input wire clk,
	input wire [3:0] button_nonFitered,
	input wire [3:0] switches,
	output reg sold_flag,
	output reg [3:0] soldItemCount,             //kaç çeşit item satıldığının sayısı
	output reg [2:0] quantitylist[0:11],  //tüm meyvelerin kaç tane alındığının listesi
	output reg [3:0] shopping_list[0:11], //shopping listi oluşturmak için kronolojik alım listesi
	output reg [9:0] highligthPosX[0:11], 
	output reg [9:0] highligthPosY[0:11]
);


reg[2:0] index; //barcode digit index
reg clk_down;   //button requires too slow clock ~10hz
integer counter;
reg [2:0] barcode[4:0];	// first 4 digit barcode + last 1 digit quantity
//fruit id list used for highlighting search
reg[2:0] fruit_list[0:11][0:3] = '{ 
'{3,1,2,1},'{3,1,2,4},'{3,1,3,3},
'{3,2,1,4},'{3,2,2,2},'{3,2,3,1},
'{4,1,3,2},'{4,1,3,3},'{4,1,3,4},
'{4,2,4,4},'{4,3,3,1},'{4,4,3,2}};

reg[9:0] fruit_posX[0:11] = '{280,400,520,280,400,520,280,400,520,280,400,520};
reg[9:0] fruit_posY[0:11] = '{5,5,5,125,125,125,245,245,245,365,365,365};

reg [3:0] rowIndex = 0;
reg [3:0] fruitIndex = 0;
reg [2:0] quantity = 0;
reg [2:0] soldItem[3:0];
reg[2:0] success_digit_count;
initial begin 
	index <= 0;
	sold_flag <= 0;
	clk_down <=0;
	success_digit_count <=0;
	barcode <= '{0,0,0,0,0};
	shopping_list[0:11] =  '{15,15,15, 15,15,15, 15,15,15, 15,15,15}; //sort according to which item sold first //15: blank
	quantitylist[0:11] = '{0,0,0, 0,0,0, 0,0,0, 0,0,0};
	soldItemCount <= 0;;
end
reg [3:0] buttons;

always @(posedge clk)begin
	if(counter < 10) //change it according to desired frequncy 
	counter <= counter + 1;
	else begin
	clk_down <= ~clk_down;
	counter <=0;
	end 
end
buttonFilter b1(clk_down,button_nonFitered[0],buttons[0]);
buttonFilter b2(clk_down,button_nonFitered[1],buttons[1]);
buttonFilter b3(clk_down,button_nonFitered[2],buttons[2]);
buttonFilter b4(clk_down,button_nonFitered[3],buttons[3]);
always @(posedge clk_down)begin
	case(switches)
		4'b0000:begin  // all switches off, barcode entry mode active
			if(index < 5)begin
				case(buttons)
					4'b0001: begin
						barcode[index] <= 3'b001;  //1 inserted
						index <= index + 1;
					end
					4'b0010:begin
						barcode[index] <= 3'b010;  //2 inserted
						index <= index + 1;
					end
					4'b0100: begin 
						barcode[index] <= 3'b011;	//3 inserted
						index <= index+1;
					end
					4'b1000: begin
						barcode[index] <= 3'b100;	// 4 insterted
						index <= index+1;
					end
				endcase
				
				for(reg[3:0] fruit_index = 0; fruit_index < 12 ; fruit_index = fruit_index+1)begin
					success_digit_count = 0;
					for(reg[2:0] digit = 0; digit < 4 ; digit = digit + 1)begin
						if (fruit_list[fruit_index][digit] == barcode[digit] && digit < index) begin
							success_digit_count = success_digit_count + 1;
							if(success_digit_count == index) begin
								highligthPosX[fruit_index] <= fruit_posX[fruit_index];
								highligthPosY[fruit_index] <= fruit_posY[fruit_index];
							end
							else begin
								highligthPosX[fruit_index] <= 0;
								highligthPosY[fruit_index] <= 0;
							end
						end
						else if (barcode[digit] != 0 && fruit_list[fruit_index][digit] != barcode[digit]) begin
							highligthPosX[fruit_index] <=0;
							highligthPosY[fruit_index] <=0;
						end			
					end	
				end
				
			end
			
			else if(buttons[0] == 1'b1 && buttons[1] == 1'b1 && index == 5) begin  // sold complete, reset all
				soldItemCount <= soldItemCount + 1;
				index <= 0;
				quantity <= barcode[4];
				barcode <='{0,0,0,0,0};
				sold_flag <=1;
				for(reg [3:0] i = 0; i< 12; i = i +1)begin
					if(highligthPosX[i] !=0 && highligthPosY[i] !=0 && barcode[4] != 0)begin
						quantitylist[i] <= barcode[4];
						shopping_list[soldItemCount] = i;
					end
				end					
				for(reg [3:0] i = 0; i< 12; i = i +1)begin
					highligthPosX[i] <=0;
					highligthPosY[i] <=0;
				end
			end
			else quantity <= 0;
		end
		4'b0010:begin //sw-2 active, navigation in shopping list active
			if(buttons[3] == 1'b1 &&  rowIndex > 0) //down move
				rowIndex <= rowIndex + 1;
			else if(buttons[2] == 1 && rowIndex < soldItemCount) // up move
				rowIndex <= rowIndex -1 ;
			else if(buttons[0] == 1 && buttons[1] == 1)begin  //delete item
				quantitylist[shopping_list[rowIndex]] <= 0;
				soldItemCount <= soldItemCount - 1;
				for(reg[3:0] i = 0; i < 12; i = i +1)begin
					if(i == 11)
					shopping_list[i] <= 15;
					else if (i >= rowIndex)	
					shopping_list[i] <= shopping_list[i + 1]; //aşağıdakileri bir yukarı kaydır
				end
			end
			
		end
		4'b0100:begin //sw-3 active navigation between images active
			quantity <=0;		
			if(buttons[0] == 1'b1 &&  fruitIndex < 11) //right move
				fruitIndex <= fruitIndex + 1;
			else if(buttons[1] == 1'b1 && fruitIndex > 0)  //left move
				fruitIndex <= fruitIndex - 1;
			else if (buttons[2] == 1'b1 && fruitIndex > 2) //up move
				fruitIndex <= fruitIndex - 3;
			else if (buttons[3] == 1'b1 && fruitIndex < 9) //down move
				fruitIndex <= fruitIndex + 3;
			
			for(reg[3:0] i = 0 ; i<12 ; i = i + 1)begin
				if(i == fruitIndex)begin
					highligthPosX[fruitIndex] <= fruit_posX[fruitIndex];
					highligthPosY[fruitIndex] <= fruit_posY[fruitIndex];
				end
				else begin
					highligthPosX[i] <=0;
					highligthPosY[i] <=0;
				end
			end
		end		
		4'b1100:begin // SW4 also active, input quanitty here
			case (buttons)
				4'b0001: quantity <=1;
				4'b0010: quantity <=2;
				4'b0100: quantity <=3;
				4'b1000: quantity <=4;
			endcase
			if(quantity != 0 )begin
				soldItemCount <= soldItemCount + 1;
				shopping_list[soldItemCount]  <= fruitIndex; //
				quantitylist[fruitIndex] <= quantity;
				fruitIndex <= 0;
				quantity <= 0;
			end		
		end		
	endcase
end

endmodule