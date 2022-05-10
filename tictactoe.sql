set serveroutput on;
whenever sqlerror exit sql.sqlcode rollback;
declare
counts int;
begin
select count(*) into counts from user_tables where table_name = 'TICTACTOE';
IF counts = 1
then
--execute drop table
dbms_output.put_line('Table already exists'); else 
execute immediate 'CREATE TABLE TICTACTOE(

      B NUMBER,
      P CHAR,
      Q CHAR,
      R CHAR
    )';
 end if;
end;
/
--Insert Null Values in TICTACTOE
INSERT INTO TICTACTOE(B,P,Q,R) VALUES(1,NULL,NULL,NULL);
INSERT INTO TICTACTOE VALUES(2,NULL,NULL,NULL); 
INSERT INTO TICTACTOE(B,P,Q,R) VALUES(3,NULL,NULL,NULL);
-- Process to convert column to character
CREATE OR REPLACE FUNCTION abtocol(ab IN NUMBER) 
RETURN CHAR
IS
BEGIN
  IF ab=1 THEN
    RETURN 'P';
  ELSIF ab=2 THEN
    RETURN 'Q';
  ELSIF ab=3 THEN
    RETURN 'R';
  ELSE 
    RETURN '_';
  end if;
end;
/
-- procedure to display the game board
CREATE OR replace PROCEDURE Begin_game IS
BEGIN
  dbms_output.enable(10000);
  dbms_output.put_line(' ');
  FOR k in (SELECT * FROM tictactoe ORDER BY b) LOOP
    dbms_output.put_line(' ' || k.P || ' ' || k.Q || ' ' || k.R);
  END LOOP; 
  dbms_output.put_line(' ');
end;
/
-- game reset procedure when the game is over
CREATE OR REPLACE PROCEDURE game_restart AS
z INT;
BEGIN
  DELETE FROM TICTACTOE;
  FOR z in 1..3 LOOP
    INSERT INTO TICTACTOE VALUES (z,'_','_','_');
  END LOOP; 
  dbms_output.enable(10000);
  Begin_game();
  dbms_output.put_line('The game is ready to play : EXECUTE Play(''X'', x, b);');
end;
/
-- procedure to play
CREATE OR REPLACE PROCEDURE Play_game(var1 IN VARCHAR2, line IN NUMBER) AS
notavalidmove exception;
notavalidcol exception;
notavalidrow exception;
pragma exception_init(notavalidmove, -20000);
BEGIN
IF var1 NOT IN ('X','O') THEN
RAISE_APPLICATION_ERROR(-20000,'NOT A VALID PLAYER',FALSE);
END IF;
END;
/
--PROCESS TO CHECK INVALID COLUMN;
CREATE OR REPLACE PROCEDURE invalidcol(chars IN number) AS 
notavalidcol exception;
pragma exception_init(notavalidcol, -20000);
BEGIN
IF chars not in (1,2,3) then 
RAISE_APPLICATION_ERROR(-20000,'NOT A VALID COLUMN');
END IF;
END;
/

--Process for main game
CREATE OR REPLACE PROCEDURE maingame_part(turn IN VARCHAR, chars IN NUMBER, line IN NUMBER) IS
ab tictactoe.p%type;
colo CHAR;
turn3 CHAR;
BEGIN
  SELECT abtocol(chars) INTO colo FROM DUAL;
 BEGIN
 invalidcol(chars);
  EXECUTE IMMEDIATE ('SELECT ' || colo || ' FROM tictactoe WHERE b=' || line) INTO ab;
 exception
 when no_data_found then
 RAISE_APPLICATION_ERROR(-20000, 'You entered out of range value');
 END;

 
  IF ab='_' THEN
    EXECUTE IMMEDIATE ('UPDATE TICTACTOE SET ' || colo || '=''' || turn || ''' WHERE b=' || line);
    Play_game(turn,line);
    IF turn='X' THEN
      turn3:='O';
    ELSE
      turn3:='X';
    end if;
    Begin_game();
    dbms_output.put_line('Around ' || turn3 || '. to play : EXECUTE Play(''' || turn3 || ''', x, y);');
  ELSE
    dbms_output.enable(10000);
    dbms_output.put_line('You cannot play into this square, it is already played');
  end if;
end;
/
-- procedure to find who wins
CREATE OR REPLACE PROCEDURE champion(turn IN VARCHAR2) IS
BEGIN
  dbms_output.enable(10000);
  Begin_game();
  dbms_output.put_line('The player ' || turn || ' Won !!!'); 
  dbms_output.put_line('---------------------------------------');
  dbms_output.put_line('Starting a new game...');
  game_restart();
end;
/
-- process to find win column req
CREATE OR REPLACE FUNCTION champcol_request(numcolumn IN VARCHAR2, turn IN VARCHAR2)
RETURN VARCHAR2
IS
BEGIN
  RETURN ('SELECT COUNT(*) FROM tictactoe WHERE ' || numcolumn || ' = '''|| turn ||''' AND ' || numcolumn || ' != ''_''');
end;
/
-- procedure to find diagonal column req
CREATE OR REPLACE FUNCTION diag_col_req(numcolumn IN VARCHAR2, ab IN NUMBER)
RETURN VARCHAR2
IS
BEGIN
  RETURN ('SELECT COUNT(*) FROM TICTACTOE WHERE'|| numcolumn ||' FROM tictactoe WHERE b=' || ab);
end;
/
-- column test function
CREATE OR REPLACE FUNCTION wincol(numcolumn IN VARCHAR2)
RETURN CHAR
IS
  ab1 NUMBER;
  r VARCHAR2(256);
BEGIN
  SELECT champcol_request(numcolumn, 'X') into r FROM DUAL;
  EXECUTE IMMEDIATE r INTO ab1;
  IF ab1=3 THEN
    RETURN 'X';
  ELSIF ab1=0 THEN
    SELECT champcol_request(numcolumn, 'O') into r FROM DUAL;
    EXECUTE IMMEDIATE r INTO ab1;
    IF ab1=3 THEN
      RETURN 'O';
    end if;
  end if;
  RETURN '_';
end;
/

-- diagonal test function
CREATE OR REPLACE FUNCTION wincross(ab IN CHAR, num1 IN NUMBER, numline IN NUMBER)
RETURN CHAR
IS
  ab2 CHAR;
  ab3 CHAR;
  --temp_var VARCHAR;
  r VARCHAR2(256);
BEGIN
  SELECT champcross_request(abtocol(num1),numline) INTO r FROM DUAL; 
  IF ab IS NULL THEN 
  EXECUTE IMMEDIATE (r) INTO ab3;
  ELSIF NOT ab = '_' THEN
  EXECUTE IMMEDIATE (r) INTO ab2;
  if not ab = ab2 THEN
  ab3 := '_';
  END IF;
  ELSE
  ab3 := '_';
  END IF;
  RETURN ab3;
  END;
  /


-- test trigger if we win
CREATE OR REPLACE TRIGGER iswinner
AFTER UPDATE ON TICTACTOE
DECLARE
  CURSOR crsr IS 
    SELECT * FROM TICTACTOE ORDER BY b; 
  crval tictactoe%rowtype;
  ab2 CHAR;
  ab1 CHAR;
  ab3 CHAR;
  r VARCHAR2(40);
BEGIN
  FOR crval IN crsr LOOP
    --line test
    IF crval.P = crval.Q AND crval.Q = crval.R AND NOT crval.P='_' THEN
      champion(crval.P);
      EXIT;
    end if;
    -- colon test
    SELECT wincol(abtocol(crval.b)) INTO ab2 FROM DUAL;
    IF NOT ab2 = '_' THEN
      champion(ab2);
      EXIT;
    end if;
    -- diagonal test
    SELECT wincross(ab1, crval.b, crval.b) INTO ab1 FROM dual;
    SELECT wincross(ab3, 4-crval.b, crval.b) INTO ab3 FROM dual;
  END LOOP;
  IF NOT ab1 = '_' THEN
    champion(ab1);
    
  end if;
  IF NOT ab3 = '_' THEN
    champion(ab3);
    
  end if;
end;
/

EXECUTE game_restart;
EXECUTE maingame_part('X', 1, 1);
EXECUTE maingame_part('O', 2, 1);
EXECUTE maingame_part('X', 2, 2);
EXECUTE maingame_part('O', 3, 1);
EXECUTE maingame_part('X', 3, 3);
