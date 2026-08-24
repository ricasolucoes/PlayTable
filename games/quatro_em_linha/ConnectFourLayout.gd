class_name ConnectFourLayout
extends RefCounted

## Medidas do desenho do tabuleiro do Quatro em Linha.
##
## BoardBack, BoardFront e ConnectFourGame declaravam cada um a sua cópia de
## CELL_SIZE e do raio do furo — este último sob dois nomes, HOLE_RADIUS nos
## dois desenhos e PIECE_RADIUS no jogo, com o mesmo 34.0. Nada garantia que as
## três concordassem.
##
## As dimensões do tabuleiro em casas ficam em ConnectFourRules: são regra, não
## desenho.

## Lado da casa, em pixels.
const CELL_SIZE := 86.0

## Raio do furo e da ficha, em pixels.
const HOLE_RADIUS := 34.0

## Folga entre a borda do tabuleiro e a primeira casa.
const MARGIN := 14.0
